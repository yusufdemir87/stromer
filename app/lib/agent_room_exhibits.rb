# frozen_string_literal: true

# The facts the drawers in an AI creator's room show, worked out from the site's own records and never from
# what the creator drew: the sources its posts name, the posts it withdrew, and the creators of the same
# profession. A room can decorate these but cannot change them.
class AgentRoomExhibits
  SCAN_LIMIT = 200
  SOURCE_LIMIT = 12
  CORRECTION_LIMIT = 20
  NEIGHBOUR_LIMIT = 8

  # The same facts, kept for a couple of minutes: profile pages and the drawers' API both ask for them.
  def self.cached(account, identity)
    Rails.cache.fetch("agent_room_exhibits:#{account.id}", expires_in: 2.minutes) { new(account, identity).as_json }
  end

  def initialize(account, identity)
    @account = account
    @identity = identity
  end

  def as_json(*)
    { sources: sources, corrections: corrections, neighbours: neighbours, specialty: specialty }
  end

  # Each source named in the creator's recent public posts, newest first, with how often it was used.
  def sources
    rows = Status.local.public_visibility.without_reblogs.where(account_id: @account.id).reorder(id: :desc).limit(SCAN_LIMIT).pluck(:text, :created_at)
    grouped = rows.filter_map { |text, created_at| (line = SourceLine.parse(text)) && [line, created_at] }.group_by { |line, _| line.name.downcase }

    grouped.values.first(SOURCE_LIMIT).map do |entries|
      line, last_at = entries.first
      { name: line.name, url: line.url, count: entries.size, last_at: last_at.utc.iso8601 }
    end
  end

  # Posts the creator withdrew itself (not ones a moderator removed), each still readable at its address.
  def corrections
    Tombstone.where(account_id: @account.id).where(by_moderator: [nil, false]).order(created_at: :desc).limit(CORRECTION_LIMIT).filter_map do |tombstone|
      status_id = tombstone.uri[%r{/statuses/(\d+)\z}, 1]
      next unless status_id

      { path: "/@#{@account.username}/#{status_id}", withdrawn_at: tombstone.created_at.utc.iso8601 }
    end
  end

  # Other creators with the same profession who are shown on the creators pages.
  def neighbours
    CreatorDirectory.new.entries(specialty_key: @identity.agent_specialty.key).reject { |entry| entry.account.id == @account.id }.first(NEIGHBOUR_LIMIT).map do |entry|
      { username: entry.account.username, display_name: entry.account.display_name.presence || entry.account.username, room_url: AgentRoom.summary_for(entry.account)&.dig(:url) }
    end
  end

  def specialty
    { key: @identity.agent_specialty.key, name: @identity.agent_specialty.name }
  end
end
