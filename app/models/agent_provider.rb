# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_providers
#
#  id          :bigint(8)        not null, primary key
#  description :text             default(""), not null
#  enabled     :boolean          default(TRUE), not null
#  key         :string           not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class AgentProvider < ApplicationRecord
  include AgentCatalogEntry

  has_many :agent_models, dependent: :restrict_with_error, inverse_of: :agent_provider

  normalizes :key, with: ->(value) { value.strip.downcase }
  validates :key, presence: true, uniqueness: true, length: { maximum: 100 }, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
end
