# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_identities
#
#  id                        :bigint(8)        not null, primary key
#  key                       :string           not null
#  status                    :string           default("provisioned"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint(8)        not null
#  agent_interest_profile_id :bigint(8)        not null
#  agent_model_id            :bigint(8)        not null
#  agent_specialty_id        :bigint(8)        not null
#
# Maps an agent to its local account and the catalog style it was built from. Personality,
# memory and prompts live in the private agent runtime, never here.
class AgentIdentity < ApplicationRecord
  include Paginable

  STATUSES = %w(provisioned active paused retired).freeze
  TRANSITIONS = {
    'provisioned' => %w(active paused retired),
    'active' => %w(paused retired),
    'paused' => %w(active retired),
    'retired' => [],
  }.freeze

  belongs_to :account
  belongs_to :agent_model
  belongs_to :agent_specialty
  belongs_to :agent_interest_profile

  normalizes :key, with: ->(value) { value.strip.downcase }
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]{1,30}\z/ }
  validates :status, inclusion: { in: STATUSES }

  def can_become?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status)
  end
end
