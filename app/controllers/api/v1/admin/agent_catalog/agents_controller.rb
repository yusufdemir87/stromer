# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::AgentsController < Api::V1::Admin::AgentCatalog::BaseController
  BATCH_LIMIT = 25

  self.catalog_model = AgentIdentity
  self.catalog_serializer = REST::Admin::AgentIdentitySerializer

  before_action -> { authorize_if_got_token! :'admin:write', :'admin:write:agent_catalog' }, only: [:create, :batch, :update]

  def create
    authorize :agent_catalog, :create?

    outcome = provision(agent_params)
    render json: outcome.fetch(:body), status: outcome.fetch(:http_status)
  end

  def batch
    authorize :agent_catalog, :create?

    items = params.expect(agents: [[:key, :provider_key, :model_key, :specialty_key, :interest_profile_key, :display_name, :note]])
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

  private

  def agent_params
    params.permit(:key, :provider_key, :model_key, :specialty_key, :interest_profile_key, :display_name, :note)
  end

  def provision(attributes)
    key = attributes[:key].to_s.strip.downcase
    existing = AgentIdentity.find_by(key: key)
    return { http_status: 409, body: serialize(existing).merge('result' => 'exists') } if existing

    records = resolve_records(attributes)
    return { http_status: 422, body: { 'key' => key, 'result' => 'error', 'error' => records } } if records.is_a?(String)

    created = AgentIdentityProvisionService.new.call(
      key: key,
      display_name: attributes[:display_name],
      note: attributes[:note],
      **records
    )

    # The token appears only in this response.
    { http_status: 201, body: serialize(created.identity).merge('result' => 'created', 'access_token' => created.access_token) }
  rescue ActiveRecord::RecordInvalid => e
    { http_status: 422, body: { 'key' => key, 'result' => 'error', 'error' => e.record.errors.full_messages.to_sentence } }
  end

  # Returns the catalog records, or an error string when one is missing or disabled.
  def resolve_records(attributes)
    provider = AgentProvider.enabled.find_by(key: attributes[:provider_key].to_s)
    model = provider && AgentModel.enabled.find_by(agent_provider: provider, model_key: attributes[:model_key].to_s)
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
