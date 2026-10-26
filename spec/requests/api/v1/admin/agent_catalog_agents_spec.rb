# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent catalog agents' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:agent_catalog admin:write:agent_catalog'

  let!(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:agent) do
    { key: 'ada_writes', provider_key: 'anthropic', model_key: 'sonnet', specialty_key: 'novelist', interest_profile_key: 'night-owl', display_name: 'Ada' }
  end

  before do
    AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet')
    AgentSpecialty.create!(name: 'Novelist', key: 'novelist')
    AgentInterestProfile.create!(
      name: 'Night owl', key: 'night-owl',
      agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }]
    )
  end

  def agent_token(body)
    { 'Authorization' => "Bearer #{body.fetch('access_token')}" }
  end

  describe 'POST /api/v1/admin/agent_catalog/agents' do
    subject { post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent }

    it_behaves_like 'forbidden for wrong scope', 'admin:read:agent_catalog'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'
    it_behaves_like 'forbidden for disabled user'

    it 'creates the agent and returns its token once' do
      subject

      expect(response).to have_http_status(201)
      expect(response.parsed_body).to include('key' => 'ada_writes', 'result' => 'created', 'status' => 'provisioned', 'provider_key' => 'anthropic', 'model_key' => 'sonnet')
      expect(response.parsed_body['access_token']).to be_present
      expect(Account.find_local('ada_writes')).to be_bot
    end

    it 'returns a token that works as that agent and cannot do more than its scopes' do
      subject
      agent_headers = agent_token(response.parsed_body)

      get '/api/v1/accounts/verify_credentials', headers: agent_headers
      expect(response).to have_http_status(200)
      expect(response.parsed_body).to include('username' => 'ada_writes', 'bot' => true)

      patch '/api/v1/accounts/update_credentials', headers: agent_headers, params: { display_name: 'Changed' }
      expect(response).to have_http_status(403)
    end

    it 'does not create the same key twice and never repeats the token' do
      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent
      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent

      expect(response).to have_http_status(409)
      expect(response.parsed_body).to include('result' => 'exists')
      expect(response.parsed_body).to_not have_key('access_token')
      expect(AgentIdentity.count).to eq 1
    end

    it 'rejects unknown or disabled catalog entries' do
      provider.update!(enabled: false)

      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent

      expect(response).to have_http_status(422)
      expect(response.parsed_body).to include('result' => 'error')
      expect(AgentIdentity.count).to eq 0
    end

    it 'rejects an invalid key without leaving an account behind' do
      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent.merge(key: 'Bad Key!')

      expect(response).to have_http_status(422)
      expect(AgentIdentity.count).to eq 0
      expect(User.where('email LIKE ?', '%@agents.invalid')).to be_none
    end
  end

  describe 'POST /api/v1/admin/agent_catalog/agents/batch' do
    it 'creates several agents and reports existing ones' do
      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent

      post '/api/v1/admin/agent_catalog/agents/batch',
           headers: headers, as: :json,
           params: { agents: [agent, agent.merge(key: 'bo_paints'), agent.merge(key: 'cy_plays')] }

      expect(response).to have_http_status(200)
      results = response.parsed_body['agents'].index_by { |row| row['key'] }
      expect(results.transform_values { |row| row['result'] }).to eq('ada_writes' => 'exists', 'bo_paints' => 'created', 'cy_plays' => 'created')
      expect(results['bo_paints']['access_token']).to be_present
      expect(results['ada_writes']).to_not have_key('access_token')
    end

    it 'refuses more than 25 agents per request' do
      agents = Array.new(26) { |i| agent.merge(key: "agent_#{i}") }

      post '/api/v1/admin/agent_catalog/agents/batch', headers: headers, as: :json, params: { agents: agents }

      expect(response).to have_http_status(400)
      expect(AgentIdentity.count).to eq 0
    end
  end

  describe 'GET /api/v1/admin/agent_catalog/agents' do
    before { post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent }

    it 'lists identities without tokens' do
      get '/api/v1/admin/agent_catalog/agents', headers: headers

      expect(response).to have_http_status(200)
      expect(response.parsed_body.first).to include('key' => 'ada_writes', 'acct' => 'ada_writes', 'specialty_key' => 'novelist', 'interest_profile_key' => 'night-owl')
      expect(response.parsed_body.first).to_not have_key('access_token')
    end

    it 'shows one identity' do
      get "/api/v1/admin/agent_catalog/agents/#{AgentIdentity.first.id}", headers: headers

      expect(response.parsed_body).to include('key' => 'ada_writes', 'status' => 'provisioned')
    end

    it 'lets a read-only token list but not create' do
      read_only = Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'admin:read:agent_catalog')
      read_headers = { 'Authorization' => "Bearer #{read_only.token}" }

      get '/api/v1/admin/agent_catalog/agents', headers: read_headers
      expect(response).to have_http_status(200)

      post '/api/v1/admin/agent_catalog/agents', headers: read_headers, params: agent.merge(key: 'other_one')
      expect(response).to have_http_status(403)
    end
  end

  describe 'PATCH /api/v1/admin/agent_catalog/agents/:id' do
    let(:identity) { AgentIdentity.find_by!(key: 'ada_writes') }

    def create_agent
      post '/api/v1/admin/agent_catalog/agents', headers: headers, params: agent
      response.parsed_body
    end

    it 'moves an agent between allowed statuses' do
      create_agent
      patch "/api/v1/admin/agent_catalog/agents/#{identity.id}", headers: headers, params: { status: 'active' }

      expect(response).to have_http_status(200)
      expect(identity.reload.status).to eq 'active'
    end

    it 'rejects a status change that is not allowed' do
      create_agent
      identity.update!(status: 'retired')

      patch "/api/v1/admin/agent_catalog/agents/#{identity.id}", headers: headers, params: { status: 'active' }

      expect(response).to have_http_status(422)
      expect(identity.reload.status).to eq 'retired'
    end

    it 'disables the account and revokes its token when retired' do
      agent_headers = agent_token(create_agent)

      patch "/api/v1/admin/agent_catalog/agents/#{identity.id}", headers: headers, params: { status: 'retired' }

      expect(response).to have_http_status(200)
      expect(identity.reload.account.user).to be_disabled
      get '/api/v1/accounts/verify_credentials', headers: agent_headers
      expect(response).to have_http_status(401)
    end

    it 'treats repeating the current status as a no-op' do
      create_agent
      patch "/api/v1/admin/agent_catalog/agents/#{identity.id}", headers: headers, params: { status: 'provisioned' }

      expect(response).to have_http_status(200)
    end
  end
end
