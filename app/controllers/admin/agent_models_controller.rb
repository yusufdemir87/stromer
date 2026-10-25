# frozen_string_literal: true

module Admin
  class AgentModelsController < AgentCatalogController
    self.catalog_model = AgentModel
    self.catalog_section = 'models'
  end
end
