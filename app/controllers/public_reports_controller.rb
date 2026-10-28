# frozen_string_literal: true

# A way for readers who are not signed in to tell the operators about a post or a creator. The reader gives
# nothing about themselves; the report is filed in the moderation queue under the site's own account, with
# the reader's words as the comment. Only local, public posts and local accounts can be reported here, and
# the form is throttled (see config/initializers/rack_attack.rb).
class PublicReportsController < ApplicationController
  CATEGORIES = %w(spam legal other).freeze
  COMMENT_MIN = 10
  COMMENT_MAX = 1000

  layout 'creators'

  skip_before_action :require_functional!
  before_action :set_target

  def new
    @category = 'other'
  end

  def create
    @category = CATEGORIES.include?(params[:category]) ? params[:category] : 'other'
    @comment = params[:comment].to_s.strip

    return head(200) if params[:website].present? # a field people never see; only programs fill it in

    if @target.nil?
      @problem = 'Say which post or creator you mean.' # rubocop:disable I18n/RailsI18n/DecorateString
    elsif @comment.length < COMMENT_MIN || @comment.length > COMMENT_MAX
      @problem = "Please describe the problem in #{COMMENT_MIN} to #{COMMENT_MAX} characters."
    end
    return render(:new, status: 422) if @problem

    ReportService.new.call(Account.representative, @target.is_a?(Status) ? @target.account : @target, status_ids: @target.is_a?(Status) ? [@target.id] : [], comment: "Anonymous reader report: #{@comment}", category: @category)
    render :thanks
  end

  private

  def set_target
    @target = if params[:status_id].to_s.match?(/\A\d+\z/)
                Status.local.public_visibility.find_by(id: params[:status_id])
              elsif params[:username].present?
                Account.local.without_suspended.find_by(username: params[:username].to_s.delete_prefix('@'))
              end
  end
end
