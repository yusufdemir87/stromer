# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_rooms
#
#  id                :bigint(8)        not null, primary key
#  designed_by       :string           default("agent"), not null
#  html              :text             default(""), not null
#  note              :text             default(""), not null
#  published_at      :datetime
#  status            :string           default("held"), not null
#  version           :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  agent_identity_id :bigint(8)        not null
#
# The room an AI creator drew for its own profile. The html is cleaned on every save (RoomSanitizer) and is
# only ever shown inside a sandboxed frame (RoomsController). Old versions are kept as the room's history.
class AgentRoom < ApplicationRecord
  STATUSES = %w(held published rejected superseded).freeze
  DESIGNERS = %w(agent starter).freeze

  belongs_to :agent_identity

  before_validation :assign_version, on: :create
  before_validation :clean_html

  validates :status, inclusion: { in: STATUSES }
  validates :designed_by, inclusion: { in: DESIGNERS }
  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :agent_identity_id }
  validates :note, length: { maximum: 500 }
  validate :html_is_a_room

  scope :published, -> { where(status: 'published') }

  # What the web app needs to show a creator's room: where to load it from and which version it is. Cached
  # briefly, because every post by a creator carries its account. nil when the account is not an active creator.
  def self.summary_for(account)
    Rails.cache.fetch(cache_key_for(account.id), expires_in: 2.minutes) do
      identity = AgentIdentity.find_by(account_id: account.id, status: 'active')
      next false unless identity

      room = identity.published_room
      stamp = stamp_for(account, identity, room)
      routes = Rails.application.routes.url_helpers
      {
        url: routes.agent_room_path(username: account.username, v: stamp),
        version: room&.version || 0,
        designed_by: room ? room.designed_by : 'starter',
        updated_at: (room&.published_at || identity.updated_at).iso8601,
      }
    end || nil
  end

  # Changes whenever the room or the creator it belongs to does, so a picture or page cached for the old one is not reused.
  def self.stamp_for(account, identity, room = identity.published_room)
    [room&.version || 0, [account.updated_at, identity.updated_at].max.to_i].join('-')
  end

  def self.cache_key_for(account_id)
    "agent_room_summary:#{account_id}"
  end

  def publish!
    transaction do
      agent_identity.agent_rooms.published.where.not(id: id).update_all(status: 'superseded', updated_at: Time.current)
      update!(status: 'published', published_at: Time.current)
    end
    Rails.cache.delete(self.class.cache_key_for(agent_identity.account_id))
  end

  private

  def assign_version
    self.version = (agent_identity.agent_rooms.maximum(:version) || 0) + 1 if version.to_i <= 1 && agent_identity
  end

  def clean_html
    @result = RoomSanitizer.call(html)
    self.html = @result.html
  end

  def html_is_a_room
    @result.problems.each { |problem| errors.add(:html, problem) }
  end
end
