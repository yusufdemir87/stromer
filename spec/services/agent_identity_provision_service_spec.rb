# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentIdentityProvisionService do
  subject(:service) { described_class.new }

  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Novelist', key: 'novelist') }
  let(:profile) do
    AgentInterestProfile.create!(
      name: 'Night owl', key: 'night-owl',
      agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }]
    )
  end
  let(:attributes) { { key: 'ada_writes', agent_model: model, agent_specialty: specialty, agent_interest_profile: profile } }

  describe '#call' do
    it 'creates a confirmed, approved bot account that cannot log in with a password' do
      result = service.call(**attributes, display_name: 'Ada', note: 'Serial fiction')

      account = result.identity.account
      user = account.user
      expect(account).to have_attributes(username: 'ada_writes', display_name: 'Ada', bot: true, discoverable: true)
      expect(user).to be_confirmed
      expect(user).to be_approved
      expect(user.valid_password?('anything')).to be false
    end

    it 'links the identity to the catalog records' do
      identity = service.call(**attributes).identity

      expect(identity).to have_attributes(key: 'ada_writes', status: 'provisioned', agent_model: model, agent_specialty: specialty, agent_interest_profile: profile)
    end

    it 'returns a token limited to the agent scopes, owned by the new user' do
      result = service.call(**attributes)

      token = Doorkeeper::AccessToken.find_by(token: result.access_token)
      expect(token.resource_owner_id).to eq result.identity.account.user.id
      expect(token.scopes.to_a).to match_array(%w(read write:statuses write:follows write:favourites))
      expect(token.expires_in).to be_nil
    end

    it 'reuses one OAuth application for every agent' do
      service.call(**attributes)
      service.call(**attributes, key: 'second_agent')

      expect(Doorkeeper::Application.where(name: described_class::APPLICATION_NAME).count).to eq 1
    end

    it 'creates nothing when the identity is invalid' do
      expect { service.call(**attributes, key: 'x' * 31) }
        .to raise_error(ActiveRecord::RecordInvalid)

      expect(User.where('email LIKE ?', '%@agents.invalid')).to be_none
      expect(Doorkeeper::AccessToken.count).to eq 0
    end
  end
end
