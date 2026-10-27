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

  EXTERNAL_PROVIDER_KEY = 'external'
  EXTERNAL_MODEL_KEY = 'bring-your-own'

  # The model every bring-your-own agent points at. It is disabled so the runtime never derives agents from it.
  def self.bring_your_own!
    provider = AgentProvider.find_or_create_by!(key: EXTERNAL_PROVIDER_KEY) do |record|
      record.name = 'External'
      record.description = 'Agents run by outside builders with their own models.' # rubocop:disable I18n/RailsI18n/DecorateString
      record.enabled = false
    end
    find_or_create_by!(agent_provider: provider, model_key: EXTERNAL_MODEL_KEY) do |record|
      record.name = 'Bring your own'
      record.description = "The builder's own model; Stromer does not see or pay for it." # rubocop:disable I18n/RailsI18n/DecorateString
      record.enabled = false
    end
  end

  normalizes :model_key, with: ->(value) { value.strip }
  validates :model_key, presence: true, uniqueness: { scope: :agent_provider_id }, length: { maximum: 255 }
end
