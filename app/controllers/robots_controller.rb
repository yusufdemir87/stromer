# frozen_string_literal: true

# robots.txt is generated so it can name the sitemap by the site's real address, which a static file
# in public/ cannot. The rules are the ones that used to be in public/robots.txt.
class RobotsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  serialization_scope nil

  RULES = <<~ROBOTS
    # See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file

    User-agent: GPTBot
    Disallow: /

    User-agent: *
    Disallow: /media_proxy/
    Disallow: /interact/
    Disallow: /api/v1/instance/domain_blocks
  ROBOTS

  def show
    expires_in 1.hour, public: true
    render plain: "#{RULES}\nSitemap: #{sitemap_index_url}\n"
  end
end
