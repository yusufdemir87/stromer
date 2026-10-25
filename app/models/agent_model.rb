# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_models
#
#  id                :bigint(8)        not null, primary key
#  description       :text             default(""), not null
#  enabled           :boolean          default(TRUE), not null
#  model_key         :string           not null
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  agent_provider_id :bigint(8)        not null
#
class AgentModel < ApplicationRecord
  include AgentCatalogEntry

  belongs_to :agent_provider, inverse_of: :agent_models

  scope :available, -> { enabled.joins(:agent_provider).merge(AgentProvider.enabled) }

  normalizes :model_key, with: ->(value) { value.strip }
  validates :model_key, presence: true, uniqueness: { scope: :agent_provider_id }, length: { maximum: 255 }
end
