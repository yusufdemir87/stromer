# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent profile changes' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:agent_catalog admin:write:agent_catalog'

  let(:path) { '/api/v1/admin/agent_catalog' }
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Novelist', key: 'novelist') }
  let(:interests) { AgentInterestProfile.create!(name: 'Night owl', key: 'night-owl', agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }]) }
  let!(:identity) do
    AgentIdentityProvisionService.new.call(key: 'ada_writes', display_name: 'Ada', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity
  end

  def activate(record = identity)
    record.update!(status: 'active')
  end

  def change_profile(params)
    patch "#{path}/agents/#{identity.id}/profile", headers: headers, params: params
  end

  def agent_account
    Account.find_local('ada_writes')
  end

  describe 'PATCH /agents/:id/profile' do
    subject { patch "#{path}/agents/#{identity.id}/profile", headers: headers, params: { note: 'Writes small stories.' } }

    before { activate }

    it_behaves_like 'forbidden for wrong scope', 'admin:read:agent_catalog'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'
    it_behaves_like 'forbidden for disabled user'

    it 'changes the display name, bio and fields' do
      change_profile(display_name: 'Ada Writes', note: 'Serial fiction, one chapter a week.', fields: [{ name: 'Format', value: 'Serial' }, { name: 'Schedule', value: 'Sundays' }])

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to include('display_name' => 'Ada Writes', 'note' => 'Serial fiction, one chapter a week.')
      expect(agent_account.fields.map { |field| [field.name, field.value] }).to eq [%w(Format Serial), %w(Schedule Sundays)]
    end

    it 'leaves what it was not asked to change alone' do
      change_profile(note: 'First bio.')
      change_profile(display_name: 'Ada Again')

      expect(agent_account).to have_attributes(display_name: 'Ada Again', note: 'First bio.')
    end

    it 'does not touch the account unless the agent is active' do
      other = AgentIdentityProvisionService.new.call(key: 'bo_paints', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity

      patch "#{path}/agents/#{other.id}/profile", headers: headers, params: { note: 'Too early.' }

      expect(response).to have_http_status(422)
      expect(response.parsed_body['error']).to eq 'agent is provisioned'
      expect(Account.find_local('bo_paints').note).to eq ''
    end

    it 'refuses an empty request, too many fields and an overlong bio, and does not count them' do
      change_profile({})
      expect(response).to have_http_status(422)

      change_profile(fields: Array.new(5) { |i| { name: "n#{i}", value: "v#{i}" } })
      expect(response).to have_http_status(422)

      change_profile(note: 'x' * 501)
      expect(response).to have_http_status(422)

      3.times { |i| change_profile(note: "bio #{i}") }
      expect(response).to have_http_status(200) # the three refused attempts did not use up the allowance
    end

    it 'allows a few changes a day and then answers 429 with a Retry-After' do
      3.times { |i| change_profile(note: "bio #{i}") }
      change_profile(note: 'one too many')

      expect(response).to have_http_status(429)
      expect(response.headers['Retry-After'].to_i).to be_between(1, 86_402)
      expect(agent_account.note).to eq 'bio 2'
    end

    it 'does not give the agent more than it had: its own token still cannot edit the profile' do
      token = Doorkeeper::AccessToken.find_by(resource_owner_id: agent_account.user.id)

      patch '/api/v1/accounts/update_credentials', headers: { 'Authorization' => "Bearer #{token.token}" }, params: { display_name: 'Sneaky' }

      expect(response).to have_http_status(403)
    end
  end

  describe 'pinning' do
    before { activate }

    let!(:post_one) { Fabricate(:status, account: agent_account, text: 'First') }
    let!(:post_two) { Fabricate(:status, account: agent_account, text: 'Second') }

    it 'pins one of the agent\'s own posts and replaces the previous pin' do
      change_profile(pinned_status_id: post_one.id.to_s)
      expect(response.parsed_body['pinned_status_id']).to eq post_one.id.to_s

      change_profile(pinned_status_id: post_two.id.to_s)

      expect(agent_account.status_pins.pluck(:status_id)).to eq [post_two.id]
    end

    it 'clears the pin when the id is empty' do
      change_profile(pinned_status_id: post_one.id.to_s)

      change_profile(pinned_status_id: '')

      expect(response).to have_http_status(200)
      expect(agent_account.status_pins).to be_none
    end

    it 'refuses someone else\'s post and posts that are not public or unlisted' do
      other = Fabricate(:status, text: 'Not hers')
      private_post = Fabricate(:status, account: agent_account, text: 'Followers only', visibility: :private)

      change_profile(pinned_status_id: other.id.to_s)
      expect(response).to have_http_status(404)

      change_profile(pinned_status_id: private_post.id.to_s)
      expect(response).to have_http_status(422)
      expect(agent_account.status_pins).to be_none
    end
  end

  describe 'for a builder agent' do
    it 'is logged in the builder\'s event log' do
      builder = AgentBuilder.create!(key: 'acme', name: 'Acme', max_agents: 2)
      poet = AgentIdentityProvisionService.new.call(
        key: 'acme_poet', agent_model: AgentModel.bring_your_own!, agent_specialty: specialty, agent_interest_profile: interests, agent_builder: builder, origin: 'external'
      ).identity
      activate(poet)

      patch "#{path}/agents/#{poet.id}/profile", headers: headers, params: { note: 'Poems about the shore.' }

      expect(response).to have_http_status(200)
      expect(AgentBuilder.find_by(key: 'acme').builder_events.pluck(:kind)).to include('profile_updated')
    end
  end
end
