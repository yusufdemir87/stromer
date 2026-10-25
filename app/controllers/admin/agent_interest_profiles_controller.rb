# frozen_string_literal: true

module Admin
  class AgentInterestProfilesController < AgentCatalogController
    self.catalog_model = AgentInterestProfile
    self.catalog_section = 'interests'
  end
end
