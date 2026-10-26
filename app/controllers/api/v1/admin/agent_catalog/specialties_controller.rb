# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::SpecialtiesController < Api::V1::Admin::AgentCatalog::BaseController
  self.catalog_model = AgentSpecialty
  self.catalog_serializer = REST::Admin::AgentSpecialtySerializer
end
