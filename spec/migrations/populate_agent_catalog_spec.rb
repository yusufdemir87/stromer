# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20261029120000_populate_agent_catalog')

RSpec.describe PopulateAgentCatalog do
  subject(:populate) { described_class.new.up }

  let(:keys) { described_class::CATALOG.lines.map { |line| line.split('|').first } }

  it 'defines 100 distinct specialties and valid weighted profiles' do
    expect(keys.size).to eq 100
    expect(keys.uniq.size).to eq 100

    populate

    specialties = AgentSpecialty.where(key: keys)
    profiles = AgentInterestProfile.where(key: keys).includes(:agent_profile_interests)
    expect(specialties.size).to eq 100
    expect(profiles.size).to eq 100
    expect(specialties).to all(be_valid)
    expect(profiles).to all(be_valid)
    expect(specialties).to all(be_enabled)
    expect(profiles).to all(be_enabled)
    profiles.each do |profile|
      expect(profile.agent_profile_interests.map(&:weight)).to contain_exactly(60, 25, 15)
    end
  end

  it 'preserves operator edits, disabled entries and their interest rows on rerun' do
    populate
    specialty = AgentSpecialty.find_by!(key: keys.first)
    specialty.update!(name: 'Operator specialty', enabled: false)
    profile = AgentInterestProfile.find_by!(key: keys.first)
    profile.update!(name: 'Operator profile', enabled: false)
    profile.agent_profile_interests.order(:id).first.update!(name: 'Operator interest')
    original_specialties = AgentSpecialty.order(:id).map(&:attributes)
    original_profiles = AgentInterestProfile.order(:id).map(&:attributes)
    original_interests = AgentProfileInterest.order(:id).map(&:attributes)

    populate

    expect(AgentSpecialty.order(:id).map(&:attributes)).to eq original_specialties
    expect(AgentInterestProfile.order(:id).map(&:attributes)).to eq original_profiles
    expect(AgentProfileInterest.order(:id).map(&:attributes)).to eq original_interests
  end

  it 'preserves unrelated catalog entries without creating providers, models or agents' do
    specialty = AgentSpecialty.create!(key: 'custom_specialty', name: 'Custom specialty')

    expect { populate }.to not_change(AgentProvider, :count)
      .and not_change(AgentModel, :count)
      .and not_change(AgentIdentity, :count)
    expect(specialty.reload.name).to eq 'Custom specialty'
  end

  it 'refuses to delete potentially referenced catalog data on rollback' do
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
