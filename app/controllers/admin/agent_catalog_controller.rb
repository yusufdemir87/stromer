# frozen_string_literal: true

module Admin
  class AgentCatalogController < BaseController
    class_attribute :catalog_model, :catalog_section
    before_action :authorize_catalog
    before_action :set_record, only: [:edit, :update, :destroy]

    rescue_from ActiveRecord::NestedAttributes::TooManyRecords do
      render plain: I18n.t('admin.agent_catalog.interests.too_many'), status: 422
    end

    def index
      @records = catalog_model.alphabetical.page(params[:page]).per(25)
      if catalog_model == AgentModel
        @records = @records.includes(:agent_provider)
        @providers = AgentProvider.alphabetical.page(params[:providers_page]).per(25)
      elsif catalog_model == AgentInterestProfile
        @records = @records.includes(:agent_profile_interests)
      end
      @style_count = AgentModel.available.count * AgentSpecialty.enabled.count * AgentInterestProfile.enabled.count
      render 'admin/agent_catalog/index'
    end

    def new
      @record = catalog_model.new
      prepare_form
      render 'admin/agent_catalog/form'
    end

    def edit
      prepare_form
      render 'admin/agent_catalog/form'
    end

    def create
      @record = catalog_model.new(resource_params)
      if @record.save
        redirect_to catalog_path, notice: I18n.t('admin.agent_catalog.saved')
      else
        render_invalid
      end
    end

    def update
      if @record.update(resource_params)
        redirect_to catalog_path, notice: I18n.t('admin.agent_catalog.saved')
      else
        render_invalid
      end
    end

    def destroy
      if @record.destroy
        redirect_to catalog_path, notice: I18n.t('admin.agent_catalog.deleted')
      else
        redirect_to catalog_path, alert: @record.errors.full_messages.to_sentence
      end
    end

    private

    def authorize_catalog
      authorize :agent_catalog, { index: :index?, new: :create?, create: :create?, edit: :update?, update: :update?, destroy: :destroy? }.fetch(action_name.to_sym)
    end

    def set_record
      @record = catalog_model.find(params[:id])
    end

    def catalog_path
      catalog_model == AgentProvider ? admin_agent_models_path : polymorphic_path([:admin, catalog_model])
    end
    helper_method :catalog_path

    def prepare_form
      @providers = AgentProvider.alphabetical if catalog_model == AgentModel
      @record.agent_profile_interests.build if catalog_model == AgentInterestProfile && @record.agent_profile_interests.empty?
    end

    def render_invalid
      prepare_form
      render 'admin/agent_catalog/form', status: 422
    end

    def resource_params
      fields = [:name, :description, :enabled]
      fields += case catalog_model.name
                when 'AgentModel'
                  [:agent_provider_id, :model_key]
                when 'AgentSpecialty'
                  [:key, :capabilities]
                when 'AgentInterestProfile'
                  [:key, { agent_profile_interests_attributes: [[:id, :name, :weight, :_destroy]] }]
                else
                  [:key]
                end
      params.expect(catalog_model.model_name.param_key => fields)
    end
  end
end
