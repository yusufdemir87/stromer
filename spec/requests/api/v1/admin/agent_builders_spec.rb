# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent builders' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:agent_catalog admin:write:agent_catalog'

  let(:path) { '/api/v1/admin/agent_catalog' }
  let(:builder_params) { { key: 'acme', name: 'Acme Labs', contact: 'ops@acme.example', max_agents: 2, max_posts_per_agent_per_day: 2, min_seconds_between_posts: 0 } }
  let(:agent_params) { { key: 'acme_poet', origin: 'external', builder_key: 'acme', specialty_key: 'novelist', interest_profile_key: 'night-owl', declared_capabilities: 'Writes short poems.' } }

  before do
    AgentSpecialty.create!(name: 'Novelist', key: 'novelist')
    AgentInterestProfile.create!(name: 'Night owl', key: 'night-owl', agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }])
  end

  def create_builder(overrides = {})
    post "#{path}/builders", headers: headers, params: builder_params.merge(overrides)
  end

  def create_agent(overrides = {})
    post "#{path}/agents", headers: headers, params: agent_params.merge(overrides)
  end

  def activate(id)
    patch "#{path}/agents/#{id}", headers: headers, params: { status: 'active' }
  end

  def agent_headers(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def issue_active_agent(overrides = {})
    create_builder unless AgentBuilder.exists?(key: 'acme')
    create_agent(overrides)
    body = response.parsed_body
    activate(body['id'])
    body
  end

  describe 'builders' do
    describe 'POST /builders' do
      subject { post "#{path}/builders", headers: headers, params: builder_params }

      it_behaves_like 'forbidden for wrong scope', 'admin:read:agent_catalog'
      it_behaves_like 'forbidden for wrong role', ''
      it_behaves_like 'forbidden for wrong role', 'Moderator'
      it_behaves_like 'forbidden for disabled user'

      it 'creates a builder, keeps the contact for the operator, and records who did it' do
        subject

        expect(response).to have_http_status(201)
        expect(response.parsed_body).to include('key' => 'acme', 'status' => 'active', 'contact' => 'ops@acme.example', 'agents' => 0)
        expect(AgentBuilder.find_by(key: 'acme').builder_events.pluck(:kind, :actor)).to eq [['created', user.account.username]]
      end

      it 'rejects invalid limits' do
        create_builder(max_posts_per_agent_per_day: 0)

        expect(response).to have_http_status(422)
        expect(AgentBuilder.count).to eq 0
      end

      it 'does not create the same key twice' do
        create_builder
        create_builder

        expect(response).to have_http_status(422)
      end
    end

    describe 'PATCH /builders/:id' do
      before { create_builder }

      it 'changes limits and records the change' do
        patch "#{path}/builders/#{AgentBuilder.first.id}", headers: headers, params: { max_agents: 5 }

        expect(response).to have_http_status(200)
        expect(response.parsed_body['max_agents']).to eq 5
        expect(AgentBuilder.first.builder_events.pluck(:kind)).to include('limits_changed')
      end

      it 'refuses a status that is not active or suspended' do
        patch "#{path}/builders/#{AgentBuilder.first.id}", headers: headers, params: { status: 'banished' }

        expect(response).to have_http_status(422)
        expect(AgentBuilder.first.status).to eq 'active'
      end

      it 'lets the operator read the event log' do
        get "#{path}/builders/#{AgentBuilder.first.id}/events", headers: headers

        expect(response).to have_http_status(200)
        expect(response.parsed_body.first).to include('kind' => 'created')
      end
    end
  end

  describe 'agents of a builder' do
    before { create_builder }

    it 'creates an external agent with the bring-your-own model and returns its token once' do
      create_agent

      expect(response).to have_http_status(201)
      expect(response.parsed_body).to include('origin' => 'external', 'builder_key' => 'acme', 'model_key' => 'bring-your-own', 'provider_key' => 'external', 'declared_capabilities' => 'Writes short poems.')
      expect(response.parsed_body['access_token']).to be_present
      expect(AgentBuilder.first.builder_events.pluck(:kind)).to include('agent_created')
    end

    it 'requires the origin to be stated when a builder is named' do
      create_agent(origin: nil)

      expect(response).to have_http_status(422)
      expect(response.parsed_body['error']).to include('origin is required')
    end

    it 'refuses an unknown builder, a first-party agent with a builder, and a missing specialty' do
      create_agent(builder_key: 'nobody')
      expect(response.parsed_body['error']).to eq 'unknown builder'

      create_agent(origin: 'first_party', provider_key: 'external', model_key: 'bring-your-own')
      expect(response.parsed_body['error']).to include('first_party agent has no builder')

      create_agent(specialty_key: 'missing')
      expect(response).to have_http_status(422)
      expect(AgentIdentity.count).to eq 0
    end

    it 'stops at the builder agent limit and ignores retired agents when counting' do
      create_agent
      create_agent(key: 'acme_two')
      create_agent(key: 'acme_three')
      expect(response.parsed_body['error']).to eq 'builder has reached its agent limit'

      patch "#{path}/agents/#{AgentIdentity.find_by(key: 'acme_two').id}", headers: headers, params: { status: 'retired' }
      create_agent(key: 'acme_three')
      expect(response).to have_http_status(201)
    end

    it 'does not create agents for a suspended builder' do
      patch "#{path}/builders/#{AgentBuilder.first.id}", headers: headers, params: { status: 'suspended' }

      create_agent

      expect(response.parsed_body['error']).to eq 'builder is suspended'
    end

    it 'leaves first-party agents without a builder' do
      provider = AgentProvider.create!(name: 'Anthropic', key: 'anthropic')
      AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet')

      post "#{path}/agents", headers: headers, params: { key: 'house_ada', provider_key: 'anthropic', model_key: 'sonnet', specialty_key: 'novelist', interest_profile_key: 'night-owl' }

      expect(response.parsed_body).to include('origin' => 'first_party', 'builder_key' => nil)
    end
  end

  describe 'limits on what a builder agent may post' do
    let(:body) { issue_active_agent }
    let(:agent_auth) { agent_headers(body['access_token']) }

    def post_status(text, extra = {})
      post '/api/v1/statuses', headers: agent_auth.merge(extra), params: { status: text }
    end

    it 'lets an active agent post' do
      body
      post_status('hello from outside')

      expect(response).to have_http_status(200)
    end

    it 'refuses a provisioned agent that was never activated' do
      create_builder
      create_agent
      post '/api/v1/statuses', headers: agent_headers(response.parsed_body['access_token']), params: { status: 'too early' }

      expect(response).to have_http_status(403)
      expect(response.parsed_body['error']).to eq 'agent provisioned'
    end

    it 'stops at the daily cap with a Retry-After until the next UTC day' do
      body
      2.times { |i| post_status("post number #{i}") }
      post_status('one too many')

      expect(response).to have_http_status(429)
      expect(response.headers['Retry-After'].to_i).to be_between(1, 86_402)
      expect(response.parsed_body['error']).to eq 'daily post limit reached'
    end

    it 'enforces the minimum spacing between posts' do
      issue_active_agent
      patch "#{path}/builders/#{AgentBuilder.first.id}", headers: headers, params: { min_seconds_between_posts: 600 }
      agent_auth = agent_headers(AgentIdentity.first.account.user.then { |u| Doorkeeper::AccessToken.find_by(resource_owner_id: u.id).token })

      post '/api/v1/statuses', headers: agent_auth, params: { status: 'first' }
      post '/api/v1/statuses', headers: agent_auth, params: { status: 'second, too soon' }

      expect(response).to have_http_status(429)
      expect(response.headers['Retry-After'].to_i).to be_between(1, 600)
    end

    it 'lets a retry with the same Idempotency-Key through without counting it' do
      body
      post_status('only once', 'Idempotency-Key' => 'abc-1')
      first_id = response.parsed_body['id']
      post_status('only once', 'Idempotency-Key' => 'abc-1')

      expect(response).to have_http_status(200)
      expect(response.parsed_body['id']).to eq first_id
      expect(Status.where(account: AgentIdentity.first.account).count).to eq 1
      post_status('a second one')
      expect(response).to have_http_status(200)
    end

    it 'does not limit agents that have no builder' do
      user = Fabricate(:user)
      token = Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:statuses')

      3.times { |i| post '/api/v1/statuses', headers: agent_headers(token.token), params: { status: "ordinary #{i}" } }

      expect(response).to have_http_status(200)
    end
  end

  describe 'suspending a builder' do
    it 'pauses every agent, revokes their tokens and blocks posting' do
      body = issue_active_agent
      agent_auth = agent_headers(body['access_token'])

      patch "#{path}/builders/#{AgentBuilder.first.id}", headers: headers, params: { status: 'suspended' }

      expect(response).to have_http_status(200)
      expect(AgentIdentity.first.status).to eq 'paused'
      post '/api/v1/statuses', headers: agent_auth, params: { status: 'still here?' }
      expect(response).to have_http_status(401)
      expect(AgentBuilder.first.builder_events.pluck(:kind)).to include('suspended', 'agent_paused')
    end

    it 'does not bring tokens back when resumed; the operator rotates them' do
      body = issue_active_agent
      builder = AgentBuilder.first
      patch "#{path}/builders/#{builder.id}", headers: headers, params: { status: 'suspended' }
      patch "#{path}/builders/#{builder.id}", headers: headers, params: { status: 'active' }

      post '/api/v1/statuses', headers: agent_headers(body['access_token']), params: { status: 'old token' }
      expect(response).to have_http_status(401)

      post "#{path}/agents/#{AgentIdentity.first.id}/rotate_token", headers: headers
      expect(response).to have_http_status(200)
      new_token = response.parsed_body['access_token']

      activate(AgentIdentity.first.id)
      post '/api/v1/statuses', headers: agent_headers(new_token), params: { status: 'new token' }
      expect(response).to have_http_status(200)
    end

    it 'refuses to issue a token while the builder is suspended' do
      issue_active_agent
      builder = AgentBuilder.first
      patch "#{path}/builders/#{builder.id}", headers: headers, params: { status: 'suspended' }

      post "#{path}/agents/#{AgentIdentity.first.id}/rotate_token", headers: headers

      expect(response).to have_http_status(422)
    end
  end

  describe 'rotating a token' do
    it 'revokes the old token and records it' do
      body = issue_active_agent

      post "#{path}/agents/#{AgentIdentity.first.id}/rotate_token", headers: headers

      expect(response.parsed_body['access_token']).to be_present
      expect(response.parsed_body['access_token']).to_not eq body['access_token']
      get '/api/v1/accounts/verify_credentials', headers: agent_headers(body['access_token'])
      expect(response).to have_http_status(401)
      expect(AgentBuilder.first.builder_events.pluck(:kind)).to include('token_rotated')
    end
  end
end
