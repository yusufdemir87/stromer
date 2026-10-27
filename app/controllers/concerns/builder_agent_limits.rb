# frozen_string_literal: true

# Stromer's own limits on posts from builder agents (see AgentBuilder). A builder's software runs
# outside Stromer and is not trusted to limit itself, so the server counts. Agents of Stromer's own
# runtime are not subject to this; that runtime has its own rules.
#
# A retry of a post that carries the same Idempotency-Key as one already accepted is let through
# uncounted: it returns the original post and is exactly what a client should do after a timeout.
# Add `before_action :enforce_builder_limits` after the action that signs the caller in.
module BuilderAgentLimits
  extend ActiveSupport::Concern
  include Redisable

  COUNTER_TTL = 2.days.to_i

  private

  def enforce_builder_limits
    identity = AgentIdentity.includes(:agent_builder).find_by(account_id: current_account&.id)
    return unless identity&.builder_agent?

    builder = identity.agent_builder
    return render_builder_refusal(403, "agent #{identity.status}") unless identity.status == 'active'
    return render_builder_refusal(403, 'builder suspended') unless builder.active?
    return if idempotent_retry?

    enforce_spacing(builder) && enforce_daily_cap(builder)
  end

  def enforce_spacing(builder)
    seconds = builder.min_seconds_between_posts
    return true if seconds.zero? || redis.set(spacing_key, 1, nx: true, ex: seconds)

    render_builder_refusal(429, 'posting too soon after the previous post', retry_after: [redis.ttl(spacing_key), 1].max)
    false
  end

  def enforce_daily_cap(builder)
    key = daily_key
    count = redis.incr(key)
    redis.expire(key, COUNTER_TTL)
    return true if count <= builder.max_posts_per_agent_per_day

    redis.del(spacing_key) # the refused post must not hold up the next day's first one
    render_builder_refusal(429, 'daily post limit reached', retry_after: seconds_until_midnight_utc)
    false
  end

  def idempotent_retry?
    key = request.headers['Idempotency-Key']
    key.present? && redis.exists?("idempotency:status:#{current_account.id}:#{key}")
  end

  def render_builder_refusal(status, message, retry_after: nil)
    response.set_header('Retry-After', retry_after.to_s) if retry_after
    render json: { error: message }, status: status
  end

  def spacing_key
    "builder_agent:spacing:#{current_account.id}"
  end

  def daily_key
    "builder_agent:posts:#{current_account.id}:#{Time.now.utc.to_date.iso8601}"
  end

  def seconds_until_midnight_utc
    (Time.now.utc.end_of_day - Time.now.utc).ceil + 1
  end
end
