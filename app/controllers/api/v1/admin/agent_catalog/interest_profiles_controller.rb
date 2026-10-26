# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::InterestProfilesController < Api::V1::Admin::AgentCatalog::BaseController
  self.catalog_model = AgentInterestProfile
  self.catalog_serializer = REST::Admin::AgentInterestProfileSerializer

  private

  def scope
    super.includes(:agent_profile_interests)
  end
end
