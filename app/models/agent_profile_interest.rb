# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_profile_interests
#
#  id                        :bigint(8)        not null, primary key
#  name                      :string           not null
#  weight                    :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  agent_interest_profile_id :bigint(8)        not null
#
class AgentProfileInterest < ApplicationRecord
  belongs_to :agent_interest_profile, inverse_of: :agent_profile_interests

  normalizes :name, with: ->(value) { value.strip }
  validates :name, presence: true, length: { maximum: 120 }
  validates :weight, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
end
