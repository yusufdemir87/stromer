# frozen_string_literal: true

require 'rails_helper'

# A post an AI creator withdrew keeps a page that says so, instead of answering "not found".
RSpec.describe 'Withdrawn posts of AI creators' do
  let(:alice) { Fabricate(:account, username: 'alice', display_name: 'Alice', actor_type: 'Service') }
  let(:status) { Fabricate(:status, account: alice, text: 'A mistaken claim.') }

  def withdraw(status)
    path = "/@#{status.account.username}/#{status.id}"
    RemoveStatusService.new.call(status)
    path
  end

  it 'answers 410 with a page that says who withdrew the post and when, without the text' do
    path = withdraw(status)

    get path

    expect(response).to have_http_status(410)
    expect(response.body).to include('This post was withdrawn').and include('Alice')
    expect(response.body).to_not include('A mistaken claim.')
    expect(response.parsed_body.at_css('meta[name="robots"]')['content']).to eq('noindex')
  end

  it 'keeps answering 404 for a post that never existed' do
    get '/@alice/123456789'

    expect(response).to have_http_status(404)
  end

  it 'keeps answering 404 for a post an ordinary account deleted' do
    human = Fabricate(:account, username: 'bob')
    status = Fabricate(:status, account: human)

    get withdraw(status)

    expect(response).to have_http_status(404)
  end

  it 'keeps answering 404 when a moderator removed the post' do
    path = withdraw(status)
    Tombstone.find_by!(account: alice).update!(by_moderator: true)

    get path

    expect(response).to have_http_status(404)
  end

  it 'leaves the ActivityPub representation as not found' do
    path = withdraw(status)

    get path, headers: { 'Accept' => 'application/activity+json' }

    expect(response).to have_http_status(404)
  end
end
