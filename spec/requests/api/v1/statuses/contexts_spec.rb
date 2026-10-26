# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Statuses Contexts' do
  describe 'GET /api/v1/statuses/:status_id/context' do
    context 'with an oauth token' do
      let(:user) { Fabricate(:user) }
      let(:client_app) { Fabricate(:application, name: 'Test app', website: 'http://testapp.com') }
      let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: scopes) }
      let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

      let(:scopes) { 'read:statuses' }

      context 'with a public status' do
        let(:status) { Fabricate(:status, account: user.account) }

        before { Fabricate(:status, account: user.account, thread: status) }

        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context", headers: headers

          expect(response)
            .to have_http_status(200)
          expect(response.media_type)
            .to eq('application/json')
          expect(response.parsed_body)
            .to include(ancestors: be_an(Array).and(be_empty))
            .and include(descendants: be_an(Array).and(be_present))
        end
      end

      context 'with a public status that is a reply' do
        let(:status) { Fabricate(:status, account: user.account, thread: Fabricate(:status)) }

        before { Fabricate(:status, account: user.account, thread: status) }

        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context", headers: headers

          expect(response)
            .to have_http_status(200)
          expect(response.media_type)
            .to eq('application/json')
          expect(response.parsed_body)
            .to include(ancestors: be_an(Array).and(be_present))
            .and include(descendants: be_an(Array).and(be_present))
        end
      end
    end

    context 'without an oauth token' do
      context 'with a public status' do
        let(:status) { Fabricate(:status, visibility: :public) }

        before { Fabricate(:status, thread: status) }

        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context"

          expect(response)
            .to have_http_status(200)
          expect(response.media_type)
            .to eq('application/json')
          expect(response.parsed_body)
            .to include(ancestors: be_an(Array).and(be_empty))
            .and include(descendants: be_an(Array).and(be_present))
        end
      end

      context 'with a public status that is a reply' do
        let(:status) { Fabricate(:status, visibility: :public, thread: Fabricate(:status)) }

        before { Fabricate(:status, thread: status) }

        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context"

          expect(response)
            .to have_http_status(200)
          expect(response.media_type)
            .to eq('application/json')
          expect(response.parsed_body)
            .to include(ancestors: be_an(Array).and(be_present))
            .and include(descendants: be_an(Array).and(be_present))
        end
      end
    end
  end

  describe 'limits for anonymous readers' do
    let(:account) { Fabricate(:account) }
    let(:status) { Fabricate(:status, account: account) }

    before do
      parent = status
      4.times { parent = Fabricate(:status, account: account, thread: parent) }
    end

    def descendant_count
      get "/api/v1/statuses/#{status.id}/context"
      response.parsed_body['descendants'].size
    end

    around do |example|
      saved = ENV.fetch('ANON_CONTEXT_DEPTH_LIMIT', nil)
      example.run
    ensure
      saved.nil? ? ENV.delete('ANON_CONTEXT_DEPTH_LIMIT') : ENV['ANON_CONTEXT_DEPTH_LIMIT'] = saved
    end

    it 'shows the whole thread by default' do
      expect(descendant_count).to eq 4
    end

    it 'cuts the thread at the depth the operator set' do
      ENV['ANON_CONTEXT_DEPTH_LIMIT'] = '2'

      expect(descendant_count).to eq 2
    end

    it 'falls back to the default for an invalid value' do
      ENV['ANON_CONTEXT_DEPTH_LIMIT'] = '-3'

      expect(descendant_count).to eq 4
    end
  end
end
