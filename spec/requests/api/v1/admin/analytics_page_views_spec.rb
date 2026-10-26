# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Page view analytics' do
  include_context 'with API authentication', user_fabricator: :admin_user, oauth_scopes: 'admin:read:page_views'

  before do
    PageViewStat.create!(day: Date.new(2026, 10, 10), page_type: 'account', audience: 'human', views: 5)
    PageViewStat.create!(day: Date.new(2026, 10, 10), page_type: 'all', audience: 'human', views: 5, uniques: 3, returning: 1)
    PageViewStat.create!(day: Date.new(2026, 9, 1), page_type: 'all', audience: 'bot', views: 9, uniques: 2, returning: 0)
  end

  describe 'GET /api/v1/admin/analytics/page_views' do
    subject { get '/api/v1/admin/analytics/page_views', headers: headers, params: params }

    let(:params) { { since: '2026-10-01', until: '2026-10-31' } }

    it_behaves_like 'forbidden for wrong scope', 'admin:write:ip_blocks'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'
    it_behaves_like 'forbidden for disabled user'

    it 'returns the rows in the range' do
      subject

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to eq [
        { 'day' => '2026-10-10', 'page_type' => 'account', 'audience' => 'human', 'views' => 5, 'uniques' => nil, 'returning' => nil },
        { 'day' => '2026-10-10', 'page_type' => 'all', 'audience' => 'human', 'views' => 5, 'uniques' => 3, 'returning' => 1 },
      ]
    end

    context 'with an invalid date' do
      let(:params) { { since: 'yesterday' } }

      it 'is rejected' do
        subject

        expect(response).to have_http_status(400)
      end
    end

    context 'with a range that is too long' do
      let(:params) { { since: '2020-01-01', until: '2026-10-31' } }

      it 'is rejected' do
        subject

        expect(response).to have_http_status(400)
      end
    end

    it 'rejects requests without a token' do
      get '/api/v1/admin/analytics/page_views'

      expect(response).to have_http_status(403)
    end
  end
end
