# frozen_string_literal: true

require 'rails_helper'

# Profile and post pages carry readable content outside the JavaScript app, for crawlers that do not run it.
RSpec.describe 'Server-rendered content for crawlers' do
  let(:alice) { Fabricate(:account, username: 'alice', display_name: 'Alice', note: 'I write about lamps.') }

  def crawler_body
    response.parsed_body.at_css('#mastodon article.crawler-body')
  end

  describe 'a post page' do
    it 'contains the author and the text' do
      status = Fabricate(:status, account: alice, text: 'The lamp went out.')

      get "/@alice/#{status.id}"

      expect(crawler_body.at_css('h1').text).to include('Alice').and include('alice')
      expect(crawler_body.text).to include('The lamp went out.')
    end

    it 'shows only the content warning when there is one' do
      status = Fabricate(:status, account: alice, text: 'Secret ending', spoiler_text: 'Spoilers ahead')

      get "/@alice/#{status.id}"

      expect(crawler_body.text).to include('Spoilers ahead')
      expect(crawler_body.text).to_not include('Secret ending')
    end

    it 'escapes markup in the text' do
      status = Fabricate(:status, account: alice, text: '<script>alert(1)</script> hi')

      get "/@alice/#{status.id}"

      expect(response.body).to_not include('<script>alert(1)</script>')
      expect(crawler_body.text).to include('hi')
    end

    it 'adds nothing when the owner asked for noindex' do
      alice.user = Fabricate(:user, account: alice) if alice.user.nil?
      alice.user.settings['noindex'] = true
      alice.user.save!
      status = Fabricate(:status, account: alice, text: 'Please do not index me.')

      get "/@alice/#{status.id}"

      expect(crawler_body).to be_nil
      expect(response.parsed_body.at_css('#mastodon').text).to_not include('Please do not index me.')
    end
  end

  describe 'a profile page' do
    it 'contains the name, the bio and links to recent public posts' do
      status = Fabricate(:status, account: alice, text: 'First lamp post.')
      Fabricate(:status, account: alice, text: 'Followers only', visibility: :private)
      Fabricate(:status, account: alice, text: 'A boost', reblog: Fabricate(:status))

      get '/@alice'

      expect(crawler_body.at_css('h1').text).to eq('Alice')
      expect(crawler_body.text).to include('I write about lamps.').and include('First lamp post.')
      expect(crawler_body.css('li a').pluck('href')).to include(end_with("/@alice/#{status.id}"))
      expect(crawler_body.text).to_not include('Followers only')
      expect(crawler_body.text).to_not include('A boost')
    end

    it 'lists at most the most recent twenty posts, newest first' do
      statuses = Array.new(AccountsController::RECENT_STATUSES + 3) { |i| Fabricate(:status, account: alice, text: "Post number #{i}") }

      get '/@alice'

      hrefs = crawler_body.css('li a').pluck('href')
      expect(hrefs.size).to eq(AccountsController::RECENT_STATUSES)
      expect(hrefs.first).to end_with("/@alice/#{statuses.last.id}")
    end
  end
end
