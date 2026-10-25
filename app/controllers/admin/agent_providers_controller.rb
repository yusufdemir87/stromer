# frozen_string_literal: true

module Admin
  class AgentProvidersController < AgentCatalogController
    self.catalog_model = AgentProvider
    self.catalog_section = 'providers'

    def index
      redirect_to admin_agent_models_path
    end
  end
end
