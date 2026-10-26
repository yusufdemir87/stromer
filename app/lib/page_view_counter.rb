# frozen_string_literal: true

# Counts visits to the public pages without identifying anyone.
#
# Each visit adds one to a per-day counter for its kind of page and audience (human or bot, judged by
# the user agent, which is a guess: a crawler that pretends to be a browser counts as human), and puts
# an anonymous visitor hash into a per-day HyperLogLog. The hash is an HMAC of address and user agent
# under a key that changes every month, so it cannot be turned back into either and cannot link a
# visitor across months. Neither the address nor the user agent is stored. Redis holds the day's
# numbers; `flush` copies them into `page_view_stats` once the day is over.
#
# "Returning" for a day is the visitors who had already been seen earlier in the same month. It comes
# from HyperLogLog unions, so it is an estimate (a percent or two off), not an exact count.
class PageViewCounter
  include Redisable

  PAGE_TYPES = %w(account status tag explore about home).freeze
  KEEP = 40.days
  BOT_PATTERN = %r{bot|crawl|spider|slurp|facebookexternalhit|preview|fetch|scrape|monitor|curl|wget|python-requests|httpclient|go-http-client|okhttp|java/|libwww|headlesschrome|lighthouse}i

  def self.bot?(user_agent)
    user_agent.blank? || BOT_PATTERN.match?(user_agent)
  end

  def self.record(page_type:, ip:, user_agent:, now: Time.now.utc)
    new.record(page_type: page_type, ip: ip, user_agent: user_agent, now: now)
  end

  def self.flush(day)
    new.flush(day)
  end

  def record(page_type:, ip:, user_agent:, now: Time.now.utc)
    return unless PAGE_TYPES.include?(page_type)

    audience = self.class.bot?(user_agent) ? 'bot' : 'human'
    day = now.to_date
    views_key = views_key(day)
    visitors_key = visitors_key(day, audience)

    redis.pipelined do |pipeline|
      pipeline.hincrby(views_key, "#{page_type}:#{audience}", 1)
      pipeline.expire(views_key, KEEP.to_i)
      pipeline.pfadd(visitors_key, visitor_hash(ip, user_agent, day))
      pipeline.expire(visitors_key, KEEP.to_i)
    end
  end

  # Writes one day's numbers to the database. Safe to run again for the same day: it replaces the rows.
  def flush(day)
    day = day.to_date
    redis.hgetall(views_key(day)).each do |field, count|
      page_type, audience = field.split(':', 2)
      save(day, page_type, audience, views: count.to_i)
    end

    PageViewStat::AUDIENCES.each do |audience|
      views = PageViewStat.where(day: day, audience: audience).where.not(page_type: PageViewStat::ALL).sum(:views)
      uniques = redis.pfcount(visitors_key(day, audience))
      save(day, PageViewStat::ALL, audience, views: views, uniques: uniques, returning: returning(day, audience, uniques))
    end
  end

  private

  def returning(day, audience, uniques)
    earlier = (day.beginning_of_month...day).map { |date| visitors_key(date, audience) }
    return 0 if earlier.empty? || uniques.zero?

    seen_before = redis.pfcount(*earlier)
    [uniques + seen_before - redis.pfcount(visitors_key(day, audience), *earlier), 0].max.clamp(0, uniques)
  end

  def save(day, page_type, audience, attributes)
    row = PageViewStat.find_or_initialize_by(day: day, page_type: page_type, audience: audience)
    row.update!(attributes)
  end

  def views_key(day)
    "page_views:#{day.iso8601}"
  end

  def visitors_key(day, audience)
    "page_view_visitors:#{day.iso8601}:#{audience}"
  end

  def visitor_hash(ip, user_agent, day)
    key = OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, "page-views:#{day.strftime('%Y-%m')}")
    OpenSSL::HMAC.hexdigest('SHA256', key, "#{ip}|#{user_agent}")
  end
end
