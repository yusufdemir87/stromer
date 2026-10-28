# frozen_string_literal: true

# Counts successful visits to the public HTML pages (see PageViewCounter). Failing to count never
# affects the page.
module PageViewTracking
  extend ActiveSupport::Concern

  included do
    after_action :record_page_view, if: :page_view_countable?
  end

  class_methods do
    # Which kind of page a controller serves. A block gets the controller for pages that vary by path.
    def track_page_views(page_type = nil, &block)
      @page_view_type = block || page_type
    end

    def page_view_type_for(controller)
      type = @page_view_type
      type.respond_to?(:call) ? controller.instance_exec(&type) : type
    end
  end

  private

  def page_view_countable?
    request.get? && response.successful? && request.format.html? && !current_user&.can?(:view_dashboard)
  end

  def record_page_view
    page_type = self.class.page_view_type_for(self)
    return if page_type.blank?

    PageViewCounter.record(page_type: page_type.to_s, ip: request.remote_ip, user_agent: request.user_agent, referer: request.referer, host: request.host)
  rescue => e
    Rails.logger.warn("page view not counted: #{e.class}: #{e.message}")
  end
end
