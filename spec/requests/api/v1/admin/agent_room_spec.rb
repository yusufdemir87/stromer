# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent room proposals' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:agent_catalog admin:write:agent_catalog'

  let(:path) { '/api/v1/admin/agent_catalog' }
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Novelist', key: 'novelist') }
  let(:interests) { AgentInterestProfile.create!(name: 'Night owl', key: 'night-owl', agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }]) }
  let!(:identity) do
    AgentIdentityProvisionService.new.call(key: 'ada_writes', display_name: 'Ada', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity.tap { |i| i.update!(status: 'active') }
  end

  def room_html(label = 'Shelf')
    <<~HTML
      <svg viewBox="0 0 10 10" role="group" aria-label="Room">
        <g data-open="sources" tabindex="0" aria-label="#{label}"><rect width="1" height="1"/></g>
        <g data-open="works" tabindex="0" aria-label="Works"><rect width="1" height="1"/></g>
        <g data-open="about" tabindex="0" aria-label="About"><rect width="1" height="1"/></g>
      </svg>
    HTML
  end

  def propose(params = {})
    put "#{path}/agents/#{identity.id}/room", headers: headers, params: { html: room_html, note: 'A study with a long shelf.' }.merge(params)
  end

  describe 'PUT /agents/:id/room' do
    subject { propose }

    it_behaves_like 'forbidden for wrong scope', 'admin:read:agent_catalog'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'
    it_behaves_like 'forbidden for disabled user'

    it 'holds the first room of an agent for a person to read' do
      propose

      expect(response).to have_http_status(201)
      expect(response.parsed_body).to include('status' => 'held', 'version' => 1)
      expect(identity.published_room).to be_nil
    end

    it 'publishes a later room at once' do
      identity.agent_rooms.create!(html: room_html('Old')).publish!

      propose(html: room_html('New shelf'))

      expect(response.parsed_body).to include('status' => 'published')
      expect(identity.published_room.html).to include('New shelf')
    end

    it 'still holds a later room when the runtime asks for review' do
      identity.agent_rooms.create!(html: room_html('Old')).publish!

      propose(review: 'true')

      expect(response.parsed_body).to include('status' => 'held')
      expect(identity.published_room.html).to include('Old')
    end

    it 'cleans what it is given' do
      propose(html: "#{room_html}<script>alert(1)</script>")

      expect(response).to have_http_status(201)
      expect(AgentRoom.last.html).to_not include('script')
    end

    it 'refuses a room that is not usable and says why' do
      propose(html: '<svg viewBox="0 0 1 1"><rect width="1" height="1"/></svg>')

      expect(response).to have_http_status(422)
      expect(response.parsed_body['problems']).to include(a_string_matching(/at least 3/))
      expect(AgentRoom.count).to eq 0
    end

    it 'allows only a couple of proposals every thirty days' do
      2.times { |i| identity.agent_rooms.create!(html: room_html("Shelf #{i}")) }

      propose

      expect(response).to have_http_status(429)
    end

    it 'answers with a conflict, not an error, when two proposals take the same version at once' do
      allow_any_instance_of(AgentRoom).to receive(:save).and_raise(ActiveRecord::RecordNotUnique) # rubocop:disable RSpec/AnyInstance

      propose

      expect(response).to have_http_status(409)
    end

    it 'refuses a room that is nested absurdly deep instead of failing' do
      propose(html: "<svg viewBox=\"0 0 1 1\">#{'<g>' * 3_000}#{'</g>' * 3_000}</svg>")

      expect(response).to have_http_status(422)
    end

    it 'refuses an agent that is not active' do
      identity.update!(status: 'paused')

      propose

      expect(response).to have_http_status(422)
    end
  end
end
