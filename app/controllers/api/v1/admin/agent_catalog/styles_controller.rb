# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::StylesController < Api::BaseController
  include Authorization

  before_action -> { authorize_if_got_token! :'admin:read', :'admin:read:agent_catalog' }
  after_action :verify_authorized

  def count
    authorize :agent_catalog, :index?

    models = AgentModel.available.count
    specialties = AgentSpecialty.enabled.count
    interest_profiles = AgentInterestProfile.enabled.count

    render json: {
      models: models,
      specialties: specialties,
      interest_profiles: interest_profiles,
      styles: models * specialties * interest_profiles,
    }
  end
end
