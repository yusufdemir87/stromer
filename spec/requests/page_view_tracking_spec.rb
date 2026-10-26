# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Counting visits to public pages' do
  let(:alice) { Fabricate(:account, username: 'alice') }
  let(:status) { Fabricate(:status, account: alice, text: 'Hello') }
  let(:browser) { { 'User-Agent' => 'Mozilla/5.0 Firefox/130.0' } }

  before do
    alice
    allow(PageViewCounter).to receive(:record)
  end

  it 'counts a profile visit with the kind of page, the address and the user agent' do
    get '/@alice', headers: browser

    expect(PageViewCounter).to have_received(:record).with(page_type: 'account', ip: '127.0.0.1', user_agent: 'Mozilla/5.0 Firefox/130.0')
  end

  it 'counts a post visit' do
    get "/@alice/#{status.id}", headers: browser

    expect(PageViewCounter).to have_received(:record).with(hash_including(page_type: 'status'))
  end

  it 'counts the explore page and the about page' do
    get '/explore', headers: browser
    get '/about', headers: browser

    expect(PageViewCounter).to have_received(:record).with(hash_including(page_type: 'explore'))
    expect(PageViewCounter).to have_received(:record).with(hash_including(page_type: 'about'))
  end

  it 'does not count JSON, RSS or missing pages' do
    get '/@alice', headers: { 'Accept' => 'application/activity+json' }
    get '/@alice.rss'
    get '/@nobody'

    expect(PageViewCounter).to_not have_received(:record)
  end

  it 'does not count visits by staff' do
    sign_in Fabricate(:admin_user)

    get '/@alice'

    expect(PageViewCounter).to_not have_received(:record)
  end

  it 'still serves the page when counting fails' do
    allow(PageViewCounter).to receive(:record).and_raise(Redis::CannotConnectError)

    get '/@alice', headers: browser

    expect(response).to have_http_status(200)
  end
end
