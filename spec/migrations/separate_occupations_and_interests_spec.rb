# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20261029140000_separate_occupations_and_interests')

RSpec.describe SeparateOccupationsAndInterests do
  before { PopulateAgentCatalog.new.up }

  it 'replaces the paired seed with 100 occupations and 100 independent single interests' do
    described_class.new.up

    expect(AgentSpecialty.enabled.count).to eq 100
    expect(AgentInterestProfile.enabled.count).to eq 100
    expect(AgentSpecialty.where(key: %w(doctor software_engineering machinist driver painting finance_expert)).count).to eq 6
    expect(AgentInterestProfile.where(key: %w(swimming hiking sports books technology)).count).to eq 5
    expect(AgentSpecialty.all).to all(be_valid)
    expect(AgentInterestProfile.all).to all(be_valid)
    AgentInterestProfile.find_each do |profile|
      expect(profile.agent_profile_interests.pluck(:name, :weight)).to eq [[profile.name, 100]]
    end
  end

  it 'preserves the ids used by live starters and is idempotent' do
    keys = %w(fiction_writing poetry mathematics)
    specialty_ids = AgentSpecialty.where(key: keys).pluck(:id)
    profile_ids = AgentInterestProfile.where(key: keys).pluck(:id)
    described_class.new.up
    attributes = [AgentSpecialty, AgentInterestProfile, AgentProfileInterest].map { |model| model.order(:id).map(&:attributes) }

    described_class.new.up

    expect(AgentSpecialty.where(key: keys).pluck(:id)).to match_array specialty_ids
    expect(AgentInterestProfile.where(key: keys).pluck(:id)).to match_array profile_ids
    expect([AgentSpecialty, AgentInterestProfile, AgentProfileInterest].map { |model| model.order(:id).map(&:attributes) }).to eq attributes
  end

  it 'preserves custom edits and disabled choices' do
    specialty = AgentSpecialty.find_by!(key: 'painting')
    specialty.update!(name: 'My painter', enabled: false)
    profile = AgentInterestProfile.find_by!(key: 'swimming')
    profile.update!(name: 'My swimming mix')
    mix = profile.agent_profile_interests.pluck(:name, :weight)

    described_class.new.up

    expect(specialty.reload.name).to eq 'My painter'
    expect(specialty).to_not be_enabled
    expect(profile.reload.name).to eq 'My swimming mix'
    expect(profile.agent_profile_interests.pluck(:name, :weight)).to eq mix
  end

  it 'retains obsolete referenced seed entries as disabled, without deleting identities' do
    provider = AgentProvider.create!(key: 'example', name: 'Example')
    model = AgentModel.create!(agent_provider: provider, model_key: 'example', name: 'Example')
    specialty = AgentSpecialty.find_by!(key: 'ancient_history')
    profile = AgentInterestProfile.find_by!(key: 'ancient_history')
    identity = AgentIdentity.create!(key: 'existing_agent', account: Fabricate(:account), agent_model: model, agent_specialty: specialty, agent_interest_profile: profile)

    described_class.new.up

    expect(identity.reload.agent_specialty_id).to eq specialty.id
    expect(identity.agent_interest_profile_id).to eq profile.id
    expect(specialty.reload).to_not be_enabled
    expect(profile.reload).to_not be_enabled
  end
end
