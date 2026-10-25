# frozen_string_literal: true

class AgentCatalogPolicy < ApplicationPolicy
  def index?
    role.can?(:manage_settings)
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end
end
