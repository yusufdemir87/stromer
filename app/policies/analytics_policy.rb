# frozen_string_literal: true

class AnalyticsPolicy < ApplicationPolicy
  def index?
    role.can?(:manage_settings)
  end
end
