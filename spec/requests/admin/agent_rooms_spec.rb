# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin agent rooms' do
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Poet', key: 'poet') }
  let(:interests) { AgentInterestProfile.create!(name: 'Shore', key: 'shore', agent_profile_interests_attributes: [{ name: 'Tide pools', weight: 100 }]) }
  let(:identity) do
    AgentIdentityProvisionService.new.call(key: 'tidewrack', display_name: 'Tidewrack', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity.tap { |i| i.update!(status: 'active') }
  end
  let!(:room) { identity.agent_rooms.create!(html: designed_room('Held shelf'), note: 'A tide room.') }

  def designed_room(label)
    <<~HTML
      <svg viewBox="0 0 10 10" role="group" aria-label="Room">
        <g data-open="sources" tabindex="0" aria-label="#{label}"><rect width="1" height="1"/></g>
        <g data-open="works" tabindex="0" aria-label="Works"><rect width="1" height="1"/></g>
        <g data-open="about" tabindex="0" aria-label="About"><rect width="1" height="1"/></g>
      </svg>
    HTML
  end

  it 'requires authentication' do
    get '/admin/agent_rooms'

    expect(response).to have_http_status(403)
  end

  context 'without permission' do
    before { sign_in Fabricate(:user, role: Fabricate(:user_role, permissions: UserRole::FLAGS[:view_dashboard])) }

    it 'refuses everything' do
      get '/admin/agent_rooms'
      expect(response).to have_http_status(403)

      post "/admin/agent_rooms/#{room.id}/publish"
      expect(response).to have_http_status(403)
      expect(room.reload.status).to eq 'held'
    end
  end

  context 'with permission' do
    before { sign_in Fabricate(:admin_user) }

    it 'lists the rooms that wait, each in a sandboxed frame' do
      get '/admin/agent_rooms'

      expect(response).to have_http_status(200)
      frame = response.parsed_body.at_css('iframe.agent-room-review__frame')
      expect(frame['sandbox']).to eq 'allow-scripts'
      expect(frame['src']).to eq "/admin/agent_rooms/#{room.id}/preview"
      expect(response.body).to include('A tide room.')
    end

    it 'previews a room on a page that allows nothing but the bridge' do
      get "/admin/agent_rooms/#{room.id}/preview"

      expect(response).to have_http_status(200)
      expect(response.body).to include('Held shelf')
      expect(response.headers['Content-Security-Policy']).to include("default-src 'none'", 'sandbox allow-scripts', "connect-src 'none'")
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'publishes a room' do
      post "/admin/agent_rooms/#{room.id}/publish"

      expect(response).to redirect_to('/admin/agent_rooms')
      expect(room.reload.status).to eq 'published'
      expect(identity.published_room).to eq room
    end

    it 'rejects a room' do
      post "/admin/agent_rooms/#{room.id}/reject"

      expect(room.reload.status).to eq 'rejected'
      expect(identity.published_room).to be_nil
    end

    it 'does not publish a room that is no longer waiting' do
      room.update!(status: 'rejected')

      post "/admin/agent_rooms/#{room.id}/publish"

      expect(room.reload.status).to eq 'rejected'
    end
  end
end
