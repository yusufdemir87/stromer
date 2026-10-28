# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public reports' do
  let!(:creator) { Fabricate(:account, username: 'tidewrack', display_name: 'Tidewrack') }
  let(:status) { Fabricate(:status, account: creator, text: 'A claim that is wrong') }
  let(:comment) { 'This states a made-up release number.' }

  before { Fabricate(:account, id: Account::INSTANCE_ACTOR_ID, actor_type: 'Application', username: 'mastodon.internal', domain: nil) unless Account.representative }

  describe 'GET /report' do
    it 'shows the form for a post, naming its creator' do
      get '/report', params: { status_id: status.id }

      expect(response).to have_http_status(200)
      expect(response.body).to include('Tidewrack').and include('A claim that is wrong')
      expect(response.body).to include('noindex')
    end

    it 'shows the form for a creator and for nothing in particular' do
      get '/report', params: { username: 'tidewrack' }
      expect(response.body).to include('Tidewrack')

      get '/report'
      expect(response).to have_http_status(200)
      expect(response.body).to include('Creator name or post number')
    end

    it 'does not show a post that is not public' do
      private_post = Fabricate(:status, account: creator, visibility: :private, text: 'followers only')

      get '/report', params: { status_id: private_post.id }

      expect(response.body).to_not include('followers only')
    end
  end

  describe 'POST /report' do
    it 'files a report on the post under the site account, with the reader\'s words' do
      expect { post '/report', params: { status_id: status.id, comment: comment, category: 'spam' } }.to change(Report, :count).by(1)

      report = Report.last
      expect(report).to have_attributes(account_id: Account.representative.id, target_account_id: creator.id, status_ids: [status.id], category: 'spam')
      expect(report.comment).to eq "Anonymous reader report: #{comment}"
      expect(response.body).to include('Thank you')
    end

    it 'files a report on a creator' do
      expect { post '/report', params: { username: '@tidewrack', comment: comment } }.to change(Report, :count).by(1)
      expect(Report.last.target_account_id).to eq creator.id
    end

    it 'refuses a comment that is empty, too short or too long' do
      ['', 'bad', 'x' * 1001].each do |text|
        expect { post '/report', params: { status_id: status.id, comment: text } }.to_not change(Report, :count)
        expect(response).to have_http_status(422)
      end
    end

    it 'refuses a report that names nothing' do
      expect { post '/report', params: { comment: comment } }.to_not change(Report, :count)
      expect(response).to have_http_status(422)
    end

    it 'ignores a form that a program filled in (the hidden field)' do
      expect { post '/report', params: { status_id: status.id, comment: comment, website: 'https://spam.example' } }.to_not change(Report, :count)
    end

    it 'cannot be used to report a remote account' do
      Fabricate(:account, username: 'faraway', domain: 'remote.example')

      expect { post '/report', params: { username: 'faraway', comment: comment } }.to_not change(Report, :count)
      expect(response).to have_http_status(422)
    end
  end
end
