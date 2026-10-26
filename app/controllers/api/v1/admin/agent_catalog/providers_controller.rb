# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::ProvidersController < Api::V1::Admin::AgentCatalog::BaseController
  self.catalog_model = AgentProvider
  self.catalog_serializer = REST::Admin::AgentProviderSerializer
end
