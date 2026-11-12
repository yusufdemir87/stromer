# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent rooms' do
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Poet', key: 'poet') }
  let(:interests) { AgentInterestProfile.create!(name: 'Shore', key: 'shore', agent_profile_interests_attributes: [{ name: 'Tide pools', weight: 100 }]) }
  let(:identity) do
    AgentIdentityProvisionService.new.call(key: 'tidewrack', display_name: 'Tidewrack', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity.tap { |i| i.update!(status: 'active') }
  end
  let(:account) { identity.account }

  def designed_room(label)
    <<~HTML
      <svg viewBox="0 0 10 10" role="group" aria-label="Room">
        <g data-open="sources" tabindex="0" aria-label="#{label}"><rect width="1" height="1"/></g>
        <g data-open="works" tabindex="0" aria-label="Works"><rect width="1" height="1"/></g>
        <g data-open="about" tabindex="0" aria-label="About"><rect width="1" height="1"/></g>
      </svg>
    HTML
  end

  describe 'GET /@:username/room' do
    it 'draws the starter room when nothing has been approved yet' do
      get "/@#{account.username}/room"

      expect(response).to have_http_status(200)
      expect(response.media_type).to eq 'text/html'
      expect(response.body).to include('Tidewrack&#39;s room', 'data-open="neighbours"', 'data-open="follow"')
    end

    it 'shows the approved room, not a held one' do
      held = identity.agent_rooms.create!(html: designed_room('Held shelf'))
      identity.agent_rooms.create!(html: designed_room('Approved shelf')).publish!

      get "/@#{account.username}/room"

      expect(response.body).to include('Approved shelf')
      expect(response.body).to_not include('Held shelf')
      expect(held.reload.status).to eq 'held'
    end

    it 'allows no network, no form, no nested frame and only the fixed script, inside a sandbox' do
      get "/@#{account.username}/room"
      policy = response.headers['Content-Security-Policy']

      expect(policy).to include("default-src 'none'", "connect-src 'none'", "form-action 'none'", "frame-src 'none'", "child-src 'none'", "worker-src 'none'", "media-src 'none'", "object-src 'none'", "base-uri 'none'", "frame-ancestors 'self'", 'sandbox allow-scripts')
      expect(policy).to include("script-src #{RoomDocument::BRIDGE_SOURCE}")
      expect(policy).to match(/img-src data:(;|\z)/)
      expect(policy).to_not match(/style-src[^;]*nonce/)
      expect(policy).to include("style-src 'unsafe-inline'")
      expect(response.body).to include(RoomDocument::BRIDGE)
    end

    it 'can be cached by anyone and is kept out of search results, but can be framed by the site' do
      get "/@#{account.username}/room"

      expect(response.headers['Cache-Control']).to include('public')
      expect(response.headers['X-Robots-Tag']).to eq 'noindex'
      expect(response.headers['X-Frame-Options']).to eq 'SAMEORIGIN'
    end

    it 'does not cache a refusal' do
      get '/@nobody/room'

      expect(response).to have_http_status(404)
      expect(response.headers['Cache-Control'].to_s).to_not include('public')
    end

    it 'has no room for a person' do
      person = Fabricate(:account, username: 'plainperson')

      get "/@#{person.username}/room"

      expect(response).to have_http_status(404)
    end

    it 'has no room for an agent that is not active yet' do
      identity.update!(status: 'paused')

      get "/@#{account.username}/room"

      expect(response).to have_http_status(404)
    end

    it 'has no room for a suspended agent' do
      account.suspend!

      get "/@#{account.username}/room"

      expect(response).to have_http_status(404)
    end
  end

  describe AgentRoom do
    it 'cleans the html it is given and numbers the versions' do
      first = identity.agent_rooms.create!(html: "#{designed_room('Shelf')}<script>alert(1)</script>")
      second = identity.agent_rooms.create!(html: designed_room('Shelf'))

      expect(first.html).to_not include('script')
      expect([first.version, second.version]).to eq [1, 2]
    end

    it 'refuses a room that is not usable' do
      room = identity.agent_rooms.build(html: '<svg viewBox="0 0 1 1"></svg>')

      expect(room).to_not be_valid
      expect(room.errors[:html]).to be_present
    end

    it 'supersedes the previous room when a new one is published' do
      old = identity.agent_rooms.create!(html: designed_room('Old shelf'))
      old.publish!
      current = identity.agent_rooms.create!(html: designed_room('New shelf'))
      current.publish!

      expect(old.reload.status).to eq 'superseded'
      expect(identity.published_room).to eq current
    end
  end

  describe 'the room in the account serializer' do
    def serialized(account)
      serialized_record_json(account, REST::AccountSerializer, options: { scope: nil, scope_name: :current_user })
    end

    before { Rails.cache.clear }

    it 'tells the web app where an active creator\'s room is and who drew it' do
      room = serialized(account)['room']

      expect(room).to include('designed_by' => 'starter', 'version' => 0)
      expect(room['url']).to start_with("/@#{account.username}/room?v=")
    end

    it 'follows an approved room' do
      identity.agent_rooms.create!(html: designed_room('Shelf')).publish!

      expect(serialized(account)['room']).to include('designed_by' => 'agent', 'version' => 1)
    end

    it 'says nothing for people and for creators that are not active' do
      person = Fabricate(:account, username: 'plainperson2')
      identity.update!(status: 'paused')

      expect(serialized(person)).to_not have_key('room')
      expect(serialized(account)).to_not have_key('room')
    end
  end

  describe 'the room on the creators page' do
    before { Rails.cache.clear }

    it 'is shown as a small sandboxed frame that links to the profile' do
      Fabricate(:status, account: account, text: 'Low tide.')

      get '/creators'

      link = response.parsed_body.at_css('a.creator__room')
      frame = link.at_css('iframe')
      expect(link['href']).to end_with("/@#{account.username}")
      expect(frame['src']).to start_with("/@#{account.username}/room?v=")
      expect(frame['sandbox']).to eq 'allow-scripts'
      expect(frame['aria-hidden']).to eq 'true'
    end
  end

  describe StarterRoom do
    it 'is a usable room that always passes the sanitizer, whatever the name' do
      %w(tidewrack a x_y_z zzzzzzzz).each do |username|
        html = described_class.html(Fabricate.build(:account, username: username, display_name: "<b>#{username}</b> & co"), specialty_name: 'Poet <i>')
        result = RoomSanitizer.call(html)

        expect(result).to be_valid, "#{username}: #{result.problems.join(', ')}"
        expect(result.hooks).to match_array(RoomSanitizer::HOOKS)
        expect(result.html).to_not include('<b>')
      end
    end
  end
end
