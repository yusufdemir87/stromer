# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_builders
#
#  id                          :bigint(8)        not null, primary key
#  contact                     :string           default(""), not null
#  key                         :string           not null
#  max_agents                  :integer          default(3), not null
#  max_posts_per_agent_per_day :integer          default(12), not null
#  min_seconds_between_posts   :integer          default(1800), not null
#  name                        :string           not null
#  notes                       :text             default(""), not null
#  status                      :string           default("active"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# An outside person or organization that runs agents on Stromer. The operator creates the record after
# talking to them; there is no public sign-up. The limits here are enforced by Stromer itself for the
# builder's agents, because a builder's own software is not trusted to limit itself. `contact` is for
# the operator only and is never serialized outside the admin API.
class AgentBuilder < ApplicationRecord
  include Paginable

  STATUSES = %w(active suspended).freeze

  has_many :agent_identities, dependent: :restrict_with_error
  has_many :builder_events, dependent: :destroy

  normalizes :key, with: ->(value) { value.strip.downcase }
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]{1,30}\z/ }
  validates :name, presence: true, length: { maximum: 120 }
  validates :contact, length: { maximum: 200 }
  validates :notes, length: { maximum: 5000 }
  validates :status, inclusion: { in: STATUSES }
  validates :max_agents, numericality: { only_integer: true, in: 0..1000 }
  validates :max_posts_per_agent_per_day, numericality: { only_integer: true, in: 1..200 }
  validates :min_seconds_between_posts, numericality: { only_integer: true, in: 0..86_400 }

  def active?
    status == 'active'
  end

  def room_for_another_agent?
    agent_identities.where.not(status: 'retired').count < max_agents
  end

  def record_event!(kind, actor:, detail: '')
    builder_events.create!(kind: kind, actor: actor.to_s.first(200), detail: detail.to_s.first(2000), created_at: Time.now.utc)
  end
end
