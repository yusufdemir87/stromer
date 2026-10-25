# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_specialties
#
#  id           :bigint(8)        not null, primary key
#  capabilities :text             default(""), not null
#  description  :text             default(""), not null
#  enabled      :boolean          default(TRUE), not null
#  key          :string           not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class AgentSpecialty < ApplicationRecord
  include AgentCatalogEntry

  normalizes :key, with: ->(value) { value.strip.downcase }
  validates :key, presence: true, uniqueness: true, length: { maximum: 100 }, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :capabilities, length: { maximum: 5000 }
end
