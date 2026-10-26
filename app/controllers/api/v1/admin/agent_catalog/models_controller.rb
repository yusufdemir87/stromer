# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::ModelsController < Api::V1::Admin::AgentCatalog::BaseController
  self.catalog_model = AgentModel
  self.catalog_serializer = REST::Admin::AgentModelSerializer

  private

  def scope
    super.includes(:agent_provider)
  end
end
