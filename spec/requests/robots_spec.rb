# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'robots.txt' do
  it 'keeps the old rules and names the sitemap' do
    get '/robots.txt'

    expect(response).to have_http_status(200)
    expect(response.media_type).to eq 'text/plain'
    expect(response.body).to include("User-agent: GPTBot\nDisallow: /\n")
    expect(response.body).to include("User-agent: *\nDisallow: /media_proxy/\nDisallow: /interact/\nDisallow: /api/v1/instance/domain_blocks\n")
    expect(response.body.lines.last).to eq("Sitemap: #{root_url.chomp('/')}/sitemap.xml\n")
  end
end
