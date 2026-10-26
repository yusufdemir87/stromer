# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent catalog' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:agent_catalog'

  let!(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let!(:disabled_provider) { AgentProvider.create!(name: 'Off', key: 'off', enabled: false) }
  let!(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'claude-sonnet-5-5') }

  before do
    AgentModel.create!(agent_provider: disabled_provider, name: 'Hidden', model_key: 'hidden-1')
    AgentSpecialty.create!(name: 'Novelist', key: 'novelist', capabilities: 'Serialized fiction')
    AgentInterestProfile.create!(
      name: 'Night owl',
      key: 'night-owl',
      agent_profile_interests_attributes: [{ name: 'Astronomy', weight: 60 }, { name: 'Jazz', weight: 40 }]
    )
  end

  shared_examples 'a protected catalog endpoint' do |path|
    subject { get path, headers: headers }

    it_behaves_like 'forbidden for wrong scope', 'admin:write:ip_blocks'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'
    it_behaves_like 'forbidden for disabled user'

    it 'rejects requests without a token' do
      get path

      expect(response).to have_http_status(403)
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/providers' do
    it_behaves_like 'a protected catalog endpoint', '/api/v1/admin/agent_catalog/providers'

    it 'returns enabled and disabled providers' do
      get '/api/v1/admin/agent_catalog/providers', headers: headers

      expect(response).to have_http_status(200)
      expect(response.parsed_body.pluck('key')).to contain_exactly('anthropic', 'off')
      expect(response.parsed_body.find { |row| row['key'] == 'off' }).to include('enabled' => false)
    end

    it 'filters by updated_since' do
      disabled_provider.update_columns(updated_at: 2.days.ago)

      get '/api/v1/admin/agent_catalog/providers', headers: headers, params: { updated_since: 1.day.ago.iso8601 }

      expect(response.parsed_body.pluck('key')).to eq(['anthropic'])
    end

    it 'rejects a malformed updated_since' do
      get '/api/v1/admin/agent_catalog/providers', headers: headers, params: { updated_since: 'yesterday' }

      expect(response).to have_http_status(400)
    end

    it 'paginates with Link headers' do
      get '/api/v1/admin/agent_catalog/providers', headers: headers, params: { limit: 1 }

      expect(response.parsed_body.size).to eq(1)
      expect(response.headers['Link'].to_s).to include('rel="next"')
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/models' do
    it_behaves_like 'a protected catalog endpoint', '/api/v1/admin/agent_catalog/models'

    it 'returns models with their provider key and no secrets' do
      get '/api/v1/admin/agent_catalog/models', headers: headers

      expect(response).to have_http_status(200)
      row = response.parsed_body.find { |item| item['model_key'] == 'claude-sonnet-5-5' }
      expect(row).to include('provider_key' => 'anthropic', 'name' => 'Sonnet', 'enabled' => true)
      expect(row.keys).to match_array(%w(id provider_key model_key name description enabled created_at updated_at))
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/specialties' do
    it_behaves_like 'a protected catalog endpoint', '/api/v1/admin/agent_catalog/specialties'

    it 'returns specialties with capabilities' do
      get '/api/v1/admin/agent_catalog/specialties', headers: headers

      expect(response.parsed_body.first).to include('key' => 'novelist', 'capabilities' => 'Serialized fiction')
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/interest_profiles' do
    it_behaves_like 'a protected catalog endpoint', '/api/v1/admin/agent_catalog/interest_profiles'

    it 'returns weighted interests that total 100' do
      get '/api/v1/admin/agent_catalog/interest_profiles', headers: headers

      interests = response.parsed_body.first['interests']
      expect(interests).to eq([{ 'name' => 'Astronomy', 'weight' => 60 }, { 'name' => 'Jazz', 'weight' => 40 }])
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/<resource>/:id' do
    it 'returns one record' do
      get "/api/v1/admin/agent_catalog/models/#{model.id}", headers: headers

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to include('id' => model.id.to_s)
    end

    it 'returns 404 for an unknown id' do
      get '/api/v1/admin/agent_catalog/models/0', headers: headers

      expect(response).to have_http_status(404)
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/styles/count' do
    it_behaves_like 'a protected catalog endpoint', '/api/v1/admin/agent_catalog/styles/count'

    it 'counts only available combinations' do
      get '/api/v1/admin/agent_catalog/styles/count', headers: headers

      expect(response.parsed_body).to eq('models' => 1, 'specialties' => 1, 'interest_profiles' => 1, 'styles' => 1)
    end
  end
end
