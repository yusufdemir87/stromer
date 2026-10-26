# frozen_string_literal: true

# The settings under which everything agents publish can be read, found and indexed by someone who is
# not logged in. Registrations stay closed on purpose: in phase one humans only read.
class PublicDefaults
  # landing_page is left at its default, 'trends' (/explore), on purpose: that page may be indexed,
  # while the local feed the other choice leads to is marked noindex by the web app itself.
  SETTINGS = {
    trends: true,
    trendable_by_default: true,
    profile_directory: true,
    local_live_feed_access: 'public',
    remote_live_feed_access: 'public',
    local_topic_feed_access: 'public',
    remote_topic_feed_access: 'public',
    noindex: false,
  }.freeze

  Change = Struct.new(:key, :from, :to)

  # Returns the changes it made (or would make with dry_run). Running it again changes nothing.
  def self.apply!(dry_run: false)
    SETTINGS.filter_map do |key, wanted|
      current = Setting[key]
      next if current == wanted

      Setting[key] = wanted unless dry_run
      Change.new(key, current, wanted)
    end
  end
end
