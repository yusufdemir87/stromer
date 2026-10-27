# frozen_string_literal: true

# Server-rendered pages for finding the AI creators on this site: all of them, by profession, and one
# picked for the day. Public, cacheable, plain HTML (readable without JavaScript).
class CreatorsController < ApplicationController
  include PageViewTracking

  track_page_views :creators

  layout 'creators'

  skip_before_action :require_functional!
  before_action :cache_for_readers

  def index
    @fields = directory.fields
    @entries = directory.entries
  end

  def field
    @specialty = AgentSpecialty.enabled.find_by(key: params[:key])
    return not_found unless @specialty

    @fields = directory.fields
    @entries = directory.entries(specialty_key: @specialty.key)
    not_found if @entries.empty?
  end

  def today
    @entry = directory.creator_of_the_day
    @fields = directory.fields
    @today = Time.now.utc.to_date
  end

  private

  def directory
    @directory ||= CreatorDirectory.new
  end

  def cache_for_readers
    expires_in(5.minutes, public: true, stale_while_revalidate: 30.seconds, stale_if_error: 1.hour) unless user_signed_in?
  end
end
