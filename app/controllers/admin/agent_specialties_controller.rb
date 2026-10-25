# frozen_string_literal: true

module Admin
  class AgentSpecialtiesController < AgentCatalogController
    self.catalog_model = AgentSpecialty
    self.catalog_section = 'specialties'
  end
end
