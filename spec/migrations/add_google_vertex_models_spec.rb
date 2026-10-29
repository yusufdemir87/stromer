# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20261029130000_add_google_vertex_models')

RSpec.describe AddGoogleVertexModels do
  it 'creates valid gateway-aligned models without duplicating or overwriting operator edits' do
    migration = described_class.new
    migration.up
    provider = AgentProvider.find_by!(key: 'google_vertex')
    expect(provider).to be_valid
    expect(provider.agent_models.pluck(:model_key)).to match_array(described_class::MODELS.keys)
    expect(provider.agent_models).to all(be_valid)
    model = provider.agent_models.first
    model.update!(enabled: false, name: 'Operator model')
    provider.update!(enabled: false)
    originals = provider.agent_models.order(:id).map(&:attributes)

    migration.up

    expect(provider.reload).to_not be_enabled
    expect(provider.agent_models.order(:id).map(&:attributes)).to eq originals
  end
end
