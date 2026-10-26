# frozen_string_literal: true

class SitemapsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  # Same reason as ManifestsController: never issue a session cookie for a crawler.
  serialization_scope nil

  def index
    xml = Rails.cache.fetch('sitemap/v1/index', expires_in: Sitemap::CACHE_FOR) do
      children = Sitemap::KINDS.flat_map do |kind|
        (1..Sitemap.pages(kind)).map { |page| [sitemap_page_url(kind: kind, page: page, format: :xml), nil] }
      end
      render_xml('sitemapindex', 'sitemap', children)
    end
    respond(xml)
  end

  def show
    kind = params[:kind]
    page = params[:page].to_i
    return head(404) unless Sitemap::KINDS.include?(kind) && page.between?(1, Sitemap.pages(kind))

    xml = Rails.cache.fetch("sitemap/v1/#{kind}/#{page}", expires_in: Sitemap::CACHE_FOR) do
      render_xml('urlset', 'url', Sitemap.entries(kind, page).map { |entry| [entry.url, entry.lastmod] })
    end
    respond(xml)
  end

  private

  def respond(xml)
    expires_in Sitemap::CACHE_FOR, public: true
    render xml: xml, content_type: 'application/xml'
  end

  def render_xml(root, item, rows)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.send(root, xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
        rows.each do |url, lastmod|
          xml.send(item) do
            xml.loc url
            xml.lastmod lastmod.utc.iso8601 if lastmod
          end
        end
      end
    end.to_xml
  end
end
