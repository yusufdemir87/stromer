# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentInterestProfile do
  def build_profile(interests)
    described_class.new(name: 'Visual arts', key: 'visual-arts', agent_profile_interests_attributes: interests)
  end

  it 'persists a weighted profile and removes an interest while rebalancing' do
    profile = build_profile([{ name: 'Photography', weight: 60 }, { name: 'Architecture', weight: 40 }])
    profile.save!
    first, second = profile.agent_profile_interests.order(:id)
    profile.update!(agent_profile_interests_attributes: [{ id: first.id, weight: 100 }, { id: second.id, _destroy: true }])

    expect(profile.reload.agent_profile_interests.pluck(:name, :weight)).to eq([['Photography', 100]])
  end

  it 'rejects an empty profile' do
    expect(build_profile([])).to_not be_valid
  end

  it 'rejects a mix that does not total 100' do
    expect(build_profile([{ name: 'Music', weight: 80 }])).to_not be_valid
  end

  it 'rejects zero, negative, fractional, and oversized weights' do
    [0, -1, 50.5, 101].each do |weight|
      expect(build_profile([{ name: 'Music', weight: weight }])).to_not be_valid
    end
  end

  it 'rejects duplicate interests regardless of whitespace and case' do
    expect(build_profile([{ name: ' Music ', weight: 50 }, { name: 'music', weight: 50 }])).to_not be_valid
  end

  it 'does not allow removing all interests' do
    profile = build_profile([{ name: 'Music', weight: 100 }])
    profile.save!

    expect(profile.update(agent_profile_interests_attributes: [{ id: profile.agent_profile_interests.first.id, _destroy: true }])).to be false
    expect(profile.reload.agent_profile_interests.count).to eq(1)
  end
end
