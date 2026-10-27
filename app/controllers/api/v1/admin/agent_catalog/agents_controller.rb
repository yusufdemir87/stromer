# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::AgentsController < Api::V1::Admin::AgentCatalog::BaseController
  include Redisable

  BATCH_LIMIT = 25
  # An agent's profile is its shop window; changing it all day long is not a feature.
  PROFILE_UPDATES_PER_DAY = 3

  self.catalog_model = AgentIdentity
  self.catalog_serializer = REST::Admin::AgentIdentitySerializer

  before_action -> { authorize_if_got_token! :'admin:write', :'admin:write:agent_catalog' }, only: [:create, :batch, :update, :rotate_token, :profile]

  def create
    authorize :agent_catalog, :create?

    outcome = provision(agent_params)
    render json: outcome.fetch(:body), status: outcome.fetch(:http_status)
  end

  def batch
    authorize :agent_catalog, :create?

    items = params.expect(agents: [[:key, :provider_key, :model_key, :specialty_key, :interest_profile_key, :display_name, :note, :builder_key, :origin, :declared_capabilities]])
    raise Mastodon::InvalidParameterError, "at most #{BATCH_LIMIT} agents per request" if items.size > BATCH_LIMIT

    results = items.map { |item| provision(item).fetch(:body) }
    render json: { agents: results }
  end

  def update
    authorize :agent_catalog, :update?

    identity = AgentIdentity.find(params[:id])
    status = params.expect(:status)

    if status == identity.status
      # Repeating the current state is a no-op.
    elsif identity.can_become?(status)
      apply_status!(identity, status)
    else
      return render json: { error: "cannot change status from #{identity.status} to #{status}" }, status: 422
    end

    render json: identity.reload, serializer: catalog_serializer
  end

  # The agent's own profile, changed on its behalf. The agent's token has no profile scope on purpose (the
  # broad one would also let it block, mute and the like); the runtime asks here instead, and the limits
  # live here. Only display name, bio, up to four fields and one pinned post can change.
  def profile
    authorize :agent_catalog, :update?

    identity = AgentIdentity.find(params[:id])
    account = identity.account
    return render json: { error: "agent is #{identity.status}" }, status: 422 unless identity.status == 'active'
    return render_profile_limit if profile_updates_today(account) >= PROFILE_UPDATES_PER_DAY

    attributes = profile_attributes
    return render json: { error: 'nothing to change' }, status: 422 if attributes.empty? && !params.key?(:pinned_status_id)

    AgentIdentity.transaction do
      UpdateAccountService.new.call(account, attributes, raise_error: true) if attributes.any?
      change_pin!(account, params[:pinned_status_id].presence) if params.key?(:pinned_status_id)
      identity.agent_builder&.record_event!('profile_updated', actor: current_user.account.username, detail: "#{identity.key}: #{(attributes.keys + (params.key?(:pinned_status_id) ? %w(pin) : [])).join(', ')}")
    end

    ActivityPub::UpdateDistributionWorker.perform_in(ActivityPub::UpdateDistributionWorker::DEBOUNCE_DELAY, account.id)
    count_profile_update(account)
    render json: serialize(identity).merge('display_name' => account.display_name, 'note' => account.note, 'pinned_status_id' => account.status_pins.reload.first&.status_id&.to_s)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: 422
  end

  # A fresh token for an agent whose old one was lost, leaked or revoked by a suspension. The old tokens stop working.
  def rotate_token
    authorize :agent_catalog, :update?

    identity = AgentIdentity.find(params[:id])
    user = identity.account.user
    return render json: { error: 'agent is retired' }, status: 422 if identity.status == 'retired' || user.nil?
    return render json: { error: 'builder is suspended' }, status: 422 if identity.agent_builder && !identity.agent_builder.active?

    token = AgentIdentity.transaction do
      Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil).update_all(revoked_at: Time.now.utc)
      identity.agent_builder&.record_event!('token_rotated', actor: current_user.account.username, detail: identity.key)
      AgentIdentityProvisionService.new.issue_token(user)
    end

    render json: serialize(identity).merge('access_token' => token)
  end

  private

  def profile_attributes
    given = params.permit(:display_name, :note, fields: [[:name, :value]])
    attributes = given.to_h.symbolize_keys.slice(:display_name, :note)
    attributes[:fields_attributes] = given[:fields].map { |field| { name: field[:name].to_s, value: field[:value].to_s } } if given[:fields]
    attributes
  end

  # Replaces whatever is pinned with one post of the agent's own, or clears the pin when no id is given.
  def change_pin!(account, status_id)
    account.status_pins.destroy_all
    return if status_id.nil?

    status = account.statuses.find(status_id)
    raise(ActiveRecord::RecordInvalid, StatusPin.new(account: account, status: status).tap { |pin| pin.errors.add(:base, 'only public or unlisted posts can be pinned') }) unless status.public_visibility? || status.unlisted_visibility?

    StatusPin.create!(account: account, status: status)
  end

  def render_profile_limit
    response.set_header('Retry-After', seconds_until_midnight_utc.to_s)
    render json: { error: 'too many profile changes today' }, status: 429
  end

  def profile_updates_key(account)
    "agent_profile:updates:#{account.id}:#{Time.now.utc.to_date.iso8601}"
  end

  def profile_updates_today(account)
    redis.get(profile_updates_key(account)).to_i
  end

  def count_profile_update(account)
    redis.incr(profile_updates_key(account))
    redis.expire(profile_updates_key(account), 2.days.to_i)
  end

  def seconds_until_midnight_utc
    (Time.now.utc.end_of_day - Time.now.utc).ceil + 1
  end

  def agent_params
    params.permit(:key, :provider_key, :model_key, :specialty_key, :interest_profile_key, :display_name, :note, :builder_key, :origin, :declared_capabilities)
  end

  def provision(attributes)
    key = attributes[:key].to_s.strip.downcase
    existing = AgentIdentity.find_by(key: key)
    return { http_status: 409, body: serialize(existing).merge('result' => 'exists') } if existing

    builder, origin, problem = resolve_builder(attributes)
    return { http_status: 422, body: { 'key' => key, 'result' => 'error', 'error' => problem } } if problem

    records = resolve_records(attributes, origin)
    return { http_status: 422, body: { 'key' => key, 'result' => 'error', 'error' => records } } if records.is_a?(String)

    created = AgentIdentityProvisionService.new.call(
      key: key,
      display_name: attributes[:display_name],
      note: attributes[:note],
      agent_builder: builder,
      origin: origin,
      declared_capabilities: attributes[:declared_capabilities].to_s,
      **records
    )
    builder&.record_event!('agent_created', actor: current_user.account.username, detail: "#{key} (#{origin})")

    # The token appears only in this response.
    { http_status: 201, body: serialize(created.identity).merge('result' => 'created', 'access_token' => created.access_token) }
  rescue ActiveRecord::RecordInvalid => e
    { http_status: 422, body: { 'key' => key, 'result' => 'error', 'error' => e.record.errors.full_messages.to_sentence } }
  end

  # Returns [builder, origin, nil], or [nil, nil, error text]. Builder agents must name their origin on purpose.
  def resolve_builder(attributes)
    origin = attributes[:origin].presence
    builder_key = attributes[:builder_key].to_s.strip.downcase

    return [nil, 'first_party', nil] if origin.nil? && builder_key.blank?
    return [nil, nil, 'origin must be first_party, external or managed'] unless AgentIdentity::ORIGINS.include?(origin || 'external')
    return [nil, nil, 'origin is required when a builder is named (external or managed)'] if origin.nil?
    return [nil, nil, 'a first_party agent has no builder'] if origin == 'first_party' && builder_key.present?
    return [nil, 'first_party', nil] if origin == 'first_party'

    builder = AgentBuilder.find_by(key: builder_key)
    return [nil, nil, 'unknown builder'] unless builder
    return [nil, nil, 'builder is suspended'] unless builder.active?
    return [nil, nil, 'builder has reached its agent limit'] unless builder.room_for_another_agent?

    [builder, origin, nil]
  end

  # Returns the catalog records, or an error string when one is missing or disabled.
  def resolve_records(attributes, origin = 'first_party')
    provider = AgentProvider.enabled.find_by(key: attributes[:provider_key].to_s)
    model = provider && AgentModel.enabled.find_by(agent_provider: provider, model_key: attributes[:model_key].to_s)
    model = AgentModel.bring_your_own! if origin == 'external'
    specialty = AgentSpecialty.enabled.find_by(key: attributes[:specialty_key].to_s)
    profile = AgentInterestProfile.enabled.find_by(key: attributes[:interest_profile_key].to_s)

    return 'unknown or disabled provider/model' unless model
    return 'unknown or disabled specialty' unless specialty
    return 'unknown or disabled interest profile' unless profile

    { agent_model: model, agent_specialty: specialty, agent_interest_profile: profile }
  end

  def apply_status!(identity, status)
    AgentIdentity.transaction do
      identity.update!(status: status)
      identity.agent_builder&.record_event!("agent_#{status}", actor: current_user.account.username, detail: identity.key)
      retire_account!(identity.account) if status == 'retired'
    end
  end

  def retire_account!(account)
    user = account.user
    return unless user

    user.disable!
    Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil).update_all(revoked_at: Time.now.utc)
  end

  def serialize(identity)
    catalog_serializer.new(identity).as_json.deep_stringify_keys
  end

  def scope
    super.includes(:account, agent_model: :agent_provider)
  end
end
