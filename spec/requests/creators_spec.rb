# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Creators pages' do
  let(:provider) { AgentProvider.create!(name: 'Anthropic', key: 'anthropic') }
  let(:model) { AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet') }
  let(:poet) { AgentSpecialty.create!(name: 'Poet', key: 'poet', description: 'Writes small poems.') }
  let(:chef) { AgentSpecialty.create!(name: 'Chef', key: 'chef') }
  let(:interests) do
    AgentInterestProfile.create!(name: 'Shore', key: 'shore', agent_profile_interests_attributes: [{ name: 'Tide pools', weight: 70 }, { name: 'Haiku', weight: 30 }])
  end

  def creator(key, specialty, status: 'active', posts: ['A first post.'], note: nil)
    identity = AgentIdentityProvisionService.new.call(key: key, display_name: key.titleize, note: note, agent_model: model, agent_specialty: specialty, agent_interest_profile: interests).identity
    identity.update!(status: status)
    posts.each { |text| Fabricate(:status, account: identity.account, text: text) }
    identity
  end

  describe 'GET /creators' do
    it 'lists active creators with their profession, interests, bio and latest post' do
      creator('tidewrack', poet, posts: ['Low tide.', 'The harbour shows its knees.'], note: 'Three lines every morning.')

      get '/creators'

      expect(response).to have_http_status(200)
      page = response.parsed_body
      expect(page.at_css('h1').text).to eq 'AI creators'
      card = page.at_css('article.creator')
      expect(card.text).to include('Tidewrack', 'AI agent', 'Poet', 'Tide pools and Haiku', 'Three lines every morning.', 'The harbour shows its knees.', '2 public posts')
      expect(card.at_css('a[href$="/@tidewrack"]')).to be_present
    end

    it 'shows only active creators that have posted something public' do
      creator('shown_one', poet)
      creator('not_activated', poet, status: 'provisioned')
      creator('paused_one', poet, status: 'paused')
      creator('silent_one', poet, posts: [])

      get '/creators'

      names = response.parsed_body.css('.creator__name a').map(&:text)
      expect(names).to eq ['Shown One']
    end

    it 'leaves out creators whose owner asked for noindex, and posts that are not public' do
      hidden = creator('hidden_one', poet)
      hidden.account.user.settings['noindex'] = true
      hidden.account.user.save!
      private_only = creator('private_only', poet, posts: [])
      Fabricate(:status, account: private_only.account, text: 'Followers only', visibility: :private)

      get '/creators'

      expect(response.parsed_body.css('.creator')).to be_empty
      expect(response.body).to_not include('Followers only')
    end

    it 'escapes what creators wrote' do
      creator('tidewrack', poet, posts: ['<script>alert(1)</script> hello'])

      get '/creators'

      expect(response.body).to_not include('<script>alert(1)</script>')
      expect(response.parsed_body.at_css('.creator__post').text).to include('hello')
    end

    it 'says so when nobody has posted yet' do
      get '/creators'

      expect(response.parsed_body.at_css('.creators__empty').text).to include('No creators')
    end

    it 'is cacheable for anonymous readers and works without JavaScript or login' do
      creator('tidewrack', poet)

      get '/creators'

      expect(response.headers['Cache-Control']).to include('public')
      expect(response.parsed_body.at_css('link[rel=canonical]')['href']).to end_with('/creators')
    end
  end

  describe 'GET /creators/field/:key' do
    before do
      creator('tidewrack', poet)
      creator('salt_and_stove', chef)
    end

    it 'lists only that profession and links the other professions' do
      get '/creators/field/chef'

      expect(response).to have_http_status(200)
      expect(response.parsed_body.css('.creator__name a').map(&:text)).to eq ['Salt And Stove']
      expect(response.parsed_body.css('.creators__fields a').map(&:text)).to include('Everyone', 'Chef (1)', 'Poet (1)')
      expect(response.parsed_body.at_css('.creators__fields a[aria-current]').text).to eq 'Chef (1)'
    end

    it 'is not found for an unknown profession or one with nobody to show' do
      AgentSpecialty.create!(name: 'Empty', key: 'empty')

      get '/creators/field/nonsense'
      expect(response).to have_http_status(404)

      get '/creators/field/empty'
      expect(response).to have_http_status(404)
    end
  end

  describe 'GET /creators/today' do
    it 'features one creator, the same one all day, and keeps it out of search' do
      creator('tidewrack', poet)
      creator('salt_and_stove', chef)
      creator('slow_trains', poet)

      names = Array.new(3) do
        get '/creators/today'
        expect(response.parsed_body.at_css('meta[name=robots]')['content']).to eq 'noindex'
        response.parsed_body.at_css('.creator--feature .creator__name a').text
      end

      expect(names.uniq.size).to eq 1
    end

    it 'changes with the date' do
      3.times { |i| creator("creator_#{i}", poet) }
      directory = CreatorDirectory.new

      picks = (0..6).map { |day| directory.creator_of_the_day(Date.new(2026, 10, 1) + day).account.username }

      expect(picks.uniq.size).to be > 1
    end

    it 'handles an empty site' do
      get '/creators/today'

      expect(response).to have_http_status(200)
      expect(response.parsed_body.at_css('.creators__empty')).to be_present
    end
  end

  it 'counts visits as creators page views' do
    allow(PageViewCounter).to receive(:record)

    get '/creators'

    expect(PageViewCounter).to have_received(:record).with(hash_including(page_type: 'creators'))
  end
end
