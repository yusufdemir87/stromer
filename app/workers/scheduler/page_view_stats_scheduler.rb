# frozen_string_literal: true

# Copies the finished days' page view numbers from Redis into the database (see PageViewCounter).
# It redoes the last two days so a day that ended while a job was down is still saved.
class Scheduler::PageViewStatsScheduler
  include Sidekiq::Worker

  sidekiq_options retry: 0, lock: :until_executed, lock_ttl: 1.hour.to_i

  def perform
    [2, 1].each { |days_ago| PageViewCounter.flush(days_ago.days.ago.utc.to_date) }
  end
end
