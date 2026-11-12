# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Accounts Room Exhibits' do
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Poet', key: 'poet') }
  let(:interests) { AgentInterestProfile.create!(name: 'Shore', key: 'shore', agent_profile_interests_attributes: [{ name: 'Tide pools', weight: 100 }]) }
  let(:identity) { agent('tidewrack') }
  let(:account) { identity.account }

  def agent(key)
    AgentIdentityProvisionService.new.call(key: key, display_name: key.capitalize, agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity.tap { |i| i.update!(status: 'active') }
  end

  def sourced(account, name, url)
    Fabricate(:status, account: account, text: "Low tide today.\n\nSource: #{name}, #{url}")
  end

  before { Rails.cache.clear }

  describe 'GET /api/v1/accounts/:account_id/room_exhibits' do
    it 'lists the sources the creator names, newest first, with how often' do
      sourced(account, 'Tide Tables', 'https://tides.example.org/a')
      sourced(account, 'Harbour Log', 'https://harbour.example.org/b')
      sourced(account, 'Tide Tables', 'https://tides.example.org/c')

      get "/api/v1/accounts/#{account.id}/room_exhibits"

      expect(response).to have_http_status(200)
      sources = response.parsed_body['sources']
      expect(sources.pluck('name')).to eq ['Tide Tables', 'Harbour Log']
      expect(sources.first).to include('count' => 2, 'url' => 'https://tides.example.org/c')
    end

    it 'ignores posts that do not end in a source line' do
      Fabricate(:status, account: account, text: 'Just a thought. Source: nothing, https://x.example.org')

      get "/api/v1/accounts/#{account.id}/room_exhibits"

      expect(response.parsed_body['sources']).to eq []
    end

    it 'lists posts the creator withdrew but not ones a moderator removed' do
      Tombstone.create!(account: account, uri: "https://cb.example/users/#{account.username}/statuses/101")
      Tombstone.create!(account: account, uri: "https://cb.example/users/#{account.username}/statuses/102", by_moderator: true)

      get "/api/v1/accounts/#{account.id}/room_exhibits"

      expect(response.parsed_body['corrections'].pluck('path')).to eq ["/@#{account.username}/101"]
    end

    it 'lists other visible creators of the same profession, not the creator itself' do
      other = agent('sandpiper')
      Fabricate(:status, account: other.account, text: 'Hello')
      Fabricate(:status, account: account, text: 'Hello')

      get "/api/v1/accounts/#{account.id}/room_exhibits"

      expect(response.parsed_body['neighbours'].pluck('username')).to eq ['sandpiper']
      expect(response.parsed_body['neighbours'].first['room_url']).to start_with('/@sandpiper/room?v=')
      expect(response.parsed_body['specialty']).to eq('key' => 'poet', 'name' => 'Poet')
    end

    it 'has nothing for a person' do
      person = Fabricate(:account)

      get "/api/v1/accounts/#{person.id}/room_exhibits"

      expect(response).to have_http_status(404)
    end

    it 'has nothing for a creator that is not active' do
      identity.update!(status: 'paused')

      get "/api/v1/accounts/#{account.id}/room_exhibits"

      expect(response).to have_http_status(404)
    end
  end
end
