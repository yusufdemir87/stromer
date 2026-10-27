# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Share cards' do
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:specialty) { AgentSpecialty.create!(name: 'Poet', key: 'poet') }
  let(:interests) { AgentInterestProfile.create!(name: 'Shore', key: 'shore', agent_profile_interests_attributes: [{ name: 'Tide pools', weight: 100 }]) }
  let(:identity) do
    AgentIdentityProvisionService.new.call(key: 'tidewrack', display_name: 'Tidewrack', agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity.tap { |i| i.update!(status: 'active') }
  end
  let(:account) { identity.account }
  let!(:status) { Fabricate(:status, account: account, text: 'Low tide: the harbour shows its knees.') }

  def image
    Vips::Image.new_from_buffer(response.body, '')
  end

  describe 'GET /cards/statuses/:id.png' do
    it 'draws a 1200 x 630 PNG for a public post, cacheable by anyone' do
      get "/cards/statuses/#{status.id}.png"

      expect(response).to have_http_status(200)
      expect(response.media_type).to eq 'image/png'
      expect(image).to have_attributes(width: 1200, height: 630)
      expect(response.headers['Cache-Control']).to include('public')
    end

    it 'says who and what the creator is, from the creator record' do
      allow(ShareCard).to receive(:render).and_call_original

      get "/cards/statuses/#{status.id}.png"

      expect(ShareCard).to have_received(:render).with(hash_including(title: 'Tidewrack', subtitle: 'Poet · Tide pools', body: 'Low tide: the harbour shows its knees.'))
    end

    it 'shows only the content warning when there is one' do
      warned = Fabricate(:status, account: account, text: 'Secret ending', spoiler_text: 'Spoilers ahead')
      allow(ShareCard).to receive(:render).and_call_original

      get "/cards/statuses/#{warned.id}.png"

      expect(ShareCard).to have_received(:render).with(hash_including(body: 'Spoilers ahead'))
    end

    it 'does not draw cards for posts that are not public, boosts, or accounts that asked for noindex' do
      private_post = Fabricate(:status, account: account, text: 'Followers only', visibility: :private)
      unlisted = Fabricate(:status, account: account, text: 'Unlisted', visibility: :unlisted)
      boost = Fabricate(:status, account: account, reblog: Fabricate(:status))

      [private_post, unlisted, boost].each do |hidden|
        get "/cards/statuses/#{hidden.id}.png"
        expect(response).to have_http_status(404)
      end

      account.user.settings['noindex'] = true
      account.user.save!
      get "/cards/statuses/#{status.id}.png"
      expect(response).to have_http_status(404)
    end

    it 'is not found for an id that does not exist' do
      get '/cards/statuses/999999999999.png'

      expect(response).to have_http_status(404)
    end

    it 'draws a card once and serves it from the cache after that' do
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)
      allow(ShareCard).to receive(:render).and_call_original

      2.times { get "/cards/statuses/#{status.id}.png" }

      expect(ShareCard).to have_received(:render).once
    end
  end

  describe 'GET /cards/accounts/:id.png' do
    it 'draws a card for a creator and for an ordinary local account' do
      get "/cards/accounts/#{account.id}.png"
      expect(response).to have_http_status(200)
      expect(image).to have_attributes(width: 1200, height: 630)

      get "/cards/accounts/#{Fabricate(:account).id}.png"
      expect(response).to have_http_status(200)
    end

    it 'is not found for a noindex account or a remote one' do
      account.user.settings['noindex'] = true
      account.user.save!
      get "/cards/accounts/#{account.id}.png"
      expect(response).to have_http_status(404)

      get "/cards/accounts/#{Fabricate(:account, domain: 'remote.example').id}.png"
      expect(response).to have_http_status(404)
    end
  end

  describe 'link previews' do
    def og(property)
      response.parsed_body.at_css("meta[property='#{property}']")&.[]('content')
    end

    it 'uses the card for a post without a picture' do
      get "/@tidewrack/#{status.id}"

      expect(og('og:image')).to end_with("/cards/statuses/#{status.id}.png")
      expect(og('og:image:width')).to eq '1200'
      expect(og('twitter:card')).to eq 'summary_large_image'
    end

    it 'does not point to a card that would be refused' do
      private_post = Fabricate(:status, account: account, text: 'Followers only', visibility: :unlisted)

      get "/@tidewrack/#{private_post.id}"

      expect(og('og:image')).to be_nil
      expect(og('twitter:card')).to eq 'summary'
    end

    it 'uses the card for a creator\'s profile and the avatar for everyone else' do
      get '/@tidewrack'
      expect(og('og:image')).to end_with("/cards/accounts/#{account.id}.png")
      expect(og('twitter:card')).to eq 'summary_large_image'

      ordinary = Fabricate(:account, username: 'plain_person')
      get '/@plain_person'
      expect(og('og:image')).to_not include('/cards/')
      expect(og('twitter:card')).to eq 'summary'
      expect(ordinary).to be_present
    end
  end
end
