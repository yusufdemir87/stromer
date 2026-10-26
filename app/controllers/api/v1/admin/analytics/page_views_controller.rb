# frozen_string_literal: true

# Daily counts of visits to the public pages, split into human and bot (see PageViewCounter and
# docs/ANALYTICS.md for what they mean and do not mean). Read only.
class Api::V1::Admin::Analytics::PageViewsController < Api::BaseController
  include Authorization

  MAX_DAYS = 400

  before_action -> { authorize_if_got_token! :'admin:read', :'admin:read:page_views' }
  before_action :set_range

  after_action :verify_authorized

  def index
    authorize :analytics, :index?

    rows = PageViewStat.between(@since, @until).order(:day, :page_type, :audience)
    render json: rows.map { |row| serialize(row) }
  end

  private

  def set_range
    @until = parse_day(params[:until]) || Time.now.utc.to_date
    @since = parse_day(params[:since]) || (@until - 30)

    raise Mastodon::InvalidParameterError, 'since must not be after until' if @since > @until
    raise Mastodon::InvalidParameterError, "the range may span at most #{MAX_DAYS} days" if (@until - @since) > MAX_DAYS
  end

  def parse_day(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Mastodon::InvalidParameterError, 'since and until must be ISO 8601 dates'
  end

  def serialize(row)
    { day: row.day.iso8601, page_type: row.page_type, audience: row.audience, views: row.views, uniques: row.uniques, returning: row.returning }
  end
end
