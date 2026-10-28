# frozen_string_literal: true

# What a search engine may be told about. It only lists things that are already public and that the
# owner has not asked to keep out of search: local accounts that are neither suspended, silenced,
# moved nor set to "noindex", their public posts (no boosts), and listable hashtags.
class Sitemap
  include RoutingHelper

  PER_FILE = 50_000
  KINDS = %w(accounts statuses tags pages).freeze
  CACHE_FOR = 1.hour

  Entry = Struct.new(:url, :lastmod)

  def self.pages(kind)
    [(count(kind).to_f / PER_FILE).ceil, 1].max
  end

  def self.count(kind)
    new(kind).total
  end

  def self.entries(kind, page)
    new(kind).entries(page)
  end

  def initialize(kind)
    raise ArgumentError, "unknown sitemap kind #{kind.inspect}" unless KINDS.include?(kind)

    @kind = kind
  end

  def scope
    case @kind
    when 'accounts' then accounts
    when 'statuses' then statuses
    else tags
    end
  end

  # How many entries the kind has. The `pages` kind (the creators pages) is built from the directory, not a query.
  def total
    @kind == 'pages' ? page_entries.size : scope.count
  end

  def entries(page)
    return page_entries if @kind == 'pages'

    rows = scope.offset((page - 1) * PER_FILE).limit(PER_FILE)

    case @kind
    when 'accounts'
      rows.pluck(:username, :updated_at).map { |username, at| Entry.new(short_account_url(username: username), at) }
    when 'statuses'
      rows.pluck('accounts.username', 'statuses.id', 'statuses.updated_at').map do |username, id, at|
        Entry.new(short_account_status_url(account_username: username, id: id), at)
      end
    else
      rows.pluck(:name, :last_status_at, :updated_at).map { |name, last, at| Entry.new(tag_url(name), last || at) }
    end
  end

  private

  # The creators index and one page per profession that currently has someone to show.
  def page_entries
    fields = CreatorDirectory.new.fields
    return [] if fields.empty?

    [Entry.new(creators_url, nil)] + fields.map { |field| Entry.new(creators_field_url(key: field.key), nil) }
  end

  def accounts
    Account.local.searchable.without_silenced.where.not(id: noindex_account_ids).order(:id)
  end

  def statuses
    Status.local.public_visibility.without_reblogs.joins(:account)
      .merge(Account.local.searchable.without_silenced)
      .where.not(account_id: noindex_account_ids)
      .reorder('statuses.id')
  end

  def tags
    Tag.listable.usable.where.not(last_status_at: nil).order(:id)
  end

  # Accounts that opted out (stored inside each user's settings, so it cannot be filtered in SQL) and staff
  # accounts (anyone with a role): the sitemap is for the creators, not for the people who run the site.
  def noindex_account_ids
    @noindex_account_ids ||= begin
      opted_out = User.where(account_id: Account.local.select(:id)).includes(:account).select(&:prefers_noindex?).map(&:account_id)
      opted_out | User.where.not(role_id: nil).pluck(:account_id)
    end
  end
end
