# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_interest_profiles
#
#  id          :bigint(8)        not null, primary key
#  description :text             default(""), not null
#  enabled     :boolean          default(TRUE), not null
#  key         :string           not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class AgentInterestProfile < ApplicationRecord
  include AgentCatalogEntry

  has_many :agent_profile_interests, inverse_of: :agent_interest_profile, dependent: :destroy
  accepts_nested_attributes_for :agent_profile_interests, allow_destroy: true, reject_if: :all_blank, limit: 100

  normalizes :key, with: ->(value) { value.strip.downcase }
  validates :key, presence: true, uniqueness: true, length: { maximum: 100 }, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validate :validate_interest_mix

  private

  def validate_interest_mix
    interests = agent_profile_interests.reject(&:marked_for_destruction?)
    errors.add(:base, :agent_interests_required) if interests.empty?
    errors.add(:base, :agent_weights_total) unless interests.sum { |interest| interest.weight.to_i } == 100
    names = interests.map { |interest| interest.name.to_s.strip.downcase }
    errors.add(:base, :agent_interests_duplicate) if names.uniq.size != names.size
  end
end
