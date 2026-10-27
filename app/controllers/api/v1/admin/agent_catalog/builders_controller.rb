# frozen_string_literal: true

# Outside builders and the limits Stromer enforces for their agents (see AgentBuilder). Created and
# changed by the operator only.
class Api::V1::Admin::AgentCatalog::BuildersController < Api::V1::Admin::AgentCatalog::BaseController
  self.catalog_model = AgentBuilder
  self.catalog_serializer = REST::Admin::AgentBuilderSerializer

  CREATE_FIELDS = %i(key name contact max_agents max_posts_per_agent_per_day min_seconds_between_posts notes).freeze
  UPDATE_FIELDS = (CREATE_FIELDS - [:key] + [:status]).freeze

  before_action -> { authorize_if_got_token! :'admin:write', :'admin:write:agent_catalog' }, only: [:create, :update]
  before_action -> { authorize_if_got_token! :'admin:read', :'admin:read:agent_catalog' }, only: :events

  def create
    authorize :agent_catalog, :create?

    builder = AgentBuilder.new(params.permit(*CREATE_FIELDS))
    AgentBuilder.transaction do
      builder.save!
      builder.record_event!('created', actor: actor, detail: "limits: #{limits_text(builder)}")
    end

    render json: builder, serializer: catalog_serializer, status: 201
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: 422
  end

  def update
    authorize :agent_catalog, :update?

    builder = AgentBuilder.find(params[:id])
    changes = params.permit(*UPDATE_FIELDS)

    AgentBuilder.transaction do
      builder.assign_attributes(changes.except(:status))
      builder.record_event!('limits_changed', actor: actor, detail: "limits: #{limits_text(builder)}") if builder.changed?
      builder.save!
      change_status!(builder, changes[:status]) if changes[:status].present? && changes[:status] != builder.status
    end

    render json: builder.reload, serializer: catalog_serializer
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: 422
  end

  def events
    authorize :agent_catalog, :index?

    builder = AgentBuilder.find(params[:id])
    events = builder.builder_events.order(id: :desc).limit(LIMIT)
    render json: events.map { |event| { kind: event.kind, actor: event.actor, detail: event.detail, created_at: event.created_at } }
  end

  private

  def change_status!(builder, status)
    raise(ActiveRecord::RecordInvalid, builder.tap { |record| record.errors.add(:status, 'must be active or suspended') }) unless AgentBuilder::STATUSES.include?(status)

    builder.update!(status: status)
    builder.record_event!(status == 'suspended' ? 'suspended' : 'resumed', actor: actor)
    suspend_agents!(builder) if status == 'suspended'
  end

  # Suspension is meant to stop everything now: the agents are paused and their tokens revoked. Resuming the
  # builder does not bring any of that back; the operator reactivates agents one by one and issues new tokens.
  def suspend_agents!(builder)
    builder.agent_identities.where.not(status: 'retired').find_each do |identity|
      identity.update!(status: 'paused') unless identity.status == 'paused'
      user = identity.account.user
      Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil).update_all(revoked_at: Time.now.utc) if user
      builder.record_event!('agent_paused', actor: actor, detail: identity.key)
    end
  end

  def limits_text(builder)
    "max_agents=#{builder.max_agents}, max_posts_per_agent_per_day=#{builder.max_posts_per_agent_per_day}, min_seconds_between_posts=#{builder.min_seconds_between_posts}"
  end

  def actor
    current_user.account.username
  end
end
