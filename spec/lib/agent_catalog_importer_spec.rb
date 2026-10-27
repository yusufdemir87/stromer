# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentCatalogImporter do
  subject(:result) { described_class.new(document, dry_run: dry_run).call }

  let(:dry_run) { false }
  let(:document) do
    {
      'providers' => [{ 'key' => 'acme', 'name' => 'Acme', 'models' => [{ 'model_key' => 'm1', 'name' => 'M1' }] }],
      'specialties' => [{ 'key' => 'python', 'name' => 'Python', 'capabilities' => 'Explains Python releases.' }],
      'interest_profiles' => [{ 'key' => 'python', 'name' => 'Python', 'interests' => [{ 'name' => 'Packaging', 'weight' => 60 }, { 'name' => 'Speed', 'weight' => 40 }] }],
    }
  end

  it 'creates the entries' do
    expect(result).to be_ok
    expect(result.counts['providers'][:created]).to eq 1
    expect(result.counts['models'][:created]).to eq 1
    expect(AgentSpecialty.find_by(key: 'python').capabilities).to eq 'Explains Python releases.'
    expect(AgentInterestProfile.find_by(key: 'python').agent_profile_interests.pluck(:name, :weight)).to contain_exactly(['Packaging', 60], ['Speed', 40])
    expect(AgentModel.find_by(model_key: 'm1').agent_provider.key).to eq 'acme'
  end

  it 'changes nothing when run again with the same document' do
    described_class.new(document).call
    ids = AgentProfileInterest.pluck(:id)

    expect(result).to be_ok
    expect(result.counts.values).to all(include(created: 0, updated: 0))
    expect(AgentProfileInterest.pluck(:id)).to match_array(ids)
  end

  it 'updates what changed and leaves entries that are no longer in the file alone' do
    described_class.new(document).call
    AgentSpecialty.create!(key: 'old', name: 'Old')
    document['specialties'][0]['name'] = 'Python language'
    document['interest_profiles'][0]['interests'] = [{ 'name' => 'Packaging', 'weight' => 100 }]

    expect(result).to be_ok
    expect(AgentSpecialty.find_by(key: 'python').name).to eq 'Python language'
    expect(AgentInterestProfile.find_by(key: 'python').agent_profile_interests.pluck(:name, :weight)).to eq [['Packaging', 100]]
    expect(AgentSpecialty.find_by(key: 'old')).to be_present
  end

  context 'with a dry run' do
    let(:dry_run) { true }

    it 'reports what it would do and saves nothing' do
      expect(result).to be_ok
      expect(result.counts['specialties'][:created]).to eq 1
      expect(AgentSpecialty.count).to eq 0
    end
  end

  context 'when one entry is invalid' do
    before { document['interest_profiles'][0]['interests'] = [{ 'name' => 'Packaging', 'weight' => 70 }] }

    it 'saves nothing at all and says which entry' do
      expect(result).to_not be_ok
      expect(result.errors.first).to include('interest_profiles python')
      expect(AgentSpecialty.count).to eq 0
      expect(AgentProvider.count).to eq 0
    end
  end

  it 'refuses a section that is not a list' do
    result = described_class.new({ 'specialties' => 'nope' }).call
    expect(result.errors).to eq ['specialties must be a list']
  end
end
