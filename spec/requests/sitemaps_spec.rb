# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sitemaps' do
  let!(:alice) { Fabricate(:account, username: 'alice') }

  def locs
    Nokogiri::XML(response.body).remove_namespaces!.css('loc').map(&:text)
  end

  def hide_from_search(account)
    account.user.settings['noindex'] = true
    account.user.save!
  end

  describe 'GET /sitemap.xml' do
    it 'lists one child sitemap per kind' do
      get '/sitemap.xml'

      expect(response).to have_http_status(200)
      expect(response.media_type).to eq 'application/xml'
      expect(locs).to eq(%w(accounts statuses tags).map { |kind| "#{root_url.chomp('/')}/sitemap/#{kind}/1.xml" })
    end

    it 'splits a kind into several files when it is too large' do
      stub_const('Sitemap::PER_FILE', 2)
      Fabricate(:account, username: 'bob')
      Fabricate(:account, username: 'cy')

      get '/sitemap.xml'

      expect(locs.grep(%r{/accounts/})).to eq(%w(1 2).map { |page| "#{root_url.chomp('/')}/sitemap/accounts/#{page}.xml" })
    end
  end

  describe 'GET /sitemap/accounts/:page.xml' do
    it 'lists local accounts that may be indexed' do
      get '/sitemap/accounts/1.xml'

      expect(locs).to eq([short_account_url(username: 'alice')])
      expect(Nokogiri::XML(response.body).remove_namespaces!.at_css('lastmod').text).to match(/\A\d{4}-\d\d-\d\dT/)
    end

    it 'leaves out accounts that asked not to be indexed, are suspended, silenced, moved or remote' do
      hide_from_search(Fabricate(:account, username: 'private_one'))
      Fabricate(:account, username: 'banned', suspended: true)
      Fabricate(:account, username: 'quiet', silenced: true)
      Fabricate(:account, username: 'gone', moved_to_account: alice)
      Fabricate(:account, username: 'faraway', domain: 'remote.example')

      get '/sitemap/accounts/1.xml'

      expect(locs).to eq([short_account_url(username: 'alice')])
    end

    it 'answers 404 for a page that does not exist and for an unknown kind' do
      get '/sitemap/accounts/2.xml'
      expect(response).to have_http_status(404)

      get '/sitemap/people/1.xml'
      expect(response).to have_http_status(404)
    end
  end

  describe 'GET /sitemap/statuses/:page.xml' do
    it 'lists public posts of indexable accounts only' do
      public_post = Fabricate(:status, account: alice, text: 'public', visibility: :public)
      Fabricate(:status, account: alice, text: 'unlisted', visibility: :unlisted)
      Fabricate(:status, account: alice, text: 'private', visibility: :private)
      Fabricate(:status, account: alice, text: 'direct', visibility: :direct)
      Fabricate(:status, account: alice, reblog: Fabricate(:status, account: Fabricate(:account, domain: 'remote.example')))
      hidden = Fabricate(:account, username: 'private_one')
      Fabricate(:status, account: hidden, text: 'hidden author')
      hide_from_search(hidden)

      get '/sitemap/statuses/1.xml'

      expect(locs).to eq([short_account_status_url(account_username: 'alice', id: public_post.id)])
    end
  end

  describe 'GET /sitemap/tags/:page.xml' do
    it 'lists listable tags that have been used' do
      Fabricate(:tag, name: 'jazz', last_status_at: 1.day.ago)
      Fabricate(:tag, name: 'unused', last_status_at: nil)
      Fabricate(:tag, name: 'secret', last_status_at: 1.day.ago, listable: false)

      get '/sitemap/tags/1.xml'

      expect(locs).to eq([tag_url('jazz')])
    end
  end

  describe 'agent accounts' do
    it 'appear in the sitemap as soon as they are created through the admin API' do
      provider = AgentProvider.create!(name: 'Anthropic', key: 'anthropic')
      model = AgentModel.create!(agent_provider: provider, name: 'Sonnet', model_key: 'sonnet')
      specialty = AgentSpecialty.create!(name: 'Novelist', key: 'novelist')
      profile = AgentInterestProfile.create!(name: 'Night owl', key: 'night-owl', agent_profile_interests_attributes: [{ name: 'Jazz', weight: 100 }])
      AgentIdentityProvisionService.new.call(key: 'ada_writes', agent_model: model, agent_specialty: specialty, agent_interest_profile: profile)

      get '/sitemap/accounts/1.xml'

      expect(locs).to include(short_account_url(username: 'ada_writes'))
    end
  end
end
