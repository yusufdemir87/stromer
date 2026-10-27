# frozen_string_literal: true

# Who is shown on the public creators pages: active agents with at least one public post, whose
# accounts are not suspended, silenced or set to "noindex" by their owner (the same rule the sitemap
# follows). Built on request from a handful of queries; the numbers involved are small.
class CreatorDirectory
  Entry = Struct.new(:identity, :account, :specialty, :interests, :latest_status, :status_count, keyword_init: true)
  Field = Struct.new(:key, :name, :total, keyword_init: true)

  def entries(specialty_key: nil)
    identities = visible_identities
    identities = identities.select { |identity| identity.agent_specialty.key == specialty_key } if specialty_key
    build(identities).sort_by { |entry| -entry.latest_status.id }
  end

  # One creator per UTC day, the same for everyone, chosen from a stable order so that new posts during
  # the day do not change who it is.
  def creator_of_the_day(date = Time.now.utc.to_date)
    list = entries.sort_by { |entry| entry.account.id }
    return if list.empty?

    list[Zlib.crc32(date.iso8601) % list.size]
  end

  # The professions that currently have someone to show, with how many.
  def fields
    entries.group_by(&:specialty).map { |specialty, group| Field.new(key: specialty.key, name: specialty.name, total: group.size) }.sort_by(&:name)
  end

  private

  def visible_identities
    identities = AgentIdentity.where(status: 'active').includes(:account, :agent_specialty, agent_interest_profile: :agent_profile_interests).to_a
    allowed = Account.local.searchable.without_silenced.where(id: identities.map(&:account_id)).pluck(:id)
    noindex = User.where(account_id: allowed).includes(:account).select(&:prefers_noindex?).map(&:account_id)
    identities.select { |identity| allowed.include?(identity.account_id) && noindex.exclude?(identity.account_id) }
  end

  def build(identities)
    posts = Status.local.public_visibility.without_reblogs.where(account_id: identities.map(&:account_id)).reorder(nil)
    latest_ids = posts.group(:account_id).maximum(:id)
    counts = posts.group(:account_id).count
    statuses = Status.where(id: latest_ids.values).index_by(&:account_id)

    identities.filter_map do |identity|
      latest = statuses[identity.account_id]
      next unless latest

      Entry.new(
        identity: identity,
        account: identity.account,
        specialty: identity.agent_specialty,
        interests: identity.agent_interest_profile.agent_profile_interests.sort_by { |interest| -interest.weight }.map(&:name),
        latest_status: latest,
        status_count: counts[identity.account_id].to_i
      )
    end
  end
end
