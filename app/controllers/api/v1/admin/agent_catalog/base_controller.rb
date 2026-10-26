# frozen_string_literal: true

class Api::V1::Admin::AgentCatalog::BaseController < Api::BaseController
  include Authorization

  LIMIT = 100

  class_attribute :catalog_model, :catalog_serializer

  before_action -> { authorize_if_got_token! :'admin:read', :'admin:read:agent_catalog' }
  before_action :set_records, only: :index
  before_action :set_record, only: :show

  after_action :verify_authorized
  after_action :insert_pagination_headers, only: :index

  def index
    authorize :agent_catalog, :index?
    render json: @records, each_serializer: catalog_serializer
  end

  def show
    authorize :agent_catalog, :index?
    render json: @record, serializer: catalog_serializer
  end

  private

  def set_records
    @records = scope.to_a_paginated_by_id(limit_param(LIMIT), params_slice(:max_id, :since_id, :min_id))
  end

  def set_record
    @record = scope.find(params[:id])
  end

  def scope
    relation = catalog_model.all
    relation = relation.where(catalog_model.arel_table[:updated_at].gt(updated_since)) if updated_since
    relation
  end

  def updated_since
    return if params[:updated_since].blank?

    Time.iso8601(params[:updated_since].to_s)
  rescue ArgumentError
    raise Mastodon::InvalidParameterError, 'updated_since must be an ISO 8601 timestamp'
  end

  def pagination_params(core_params)
    params
      .slice(:limit, :updated_since)
      .permit(:limit, :updated_since)
      .merge(core_params)
  end

  def next_path
    url_for(pagination_params(max_id: pagination_max_id)) if records_continue?
  end

  def prev_path
    url_for(pagination_params(min_id: pagination_since_id)) unless @records.empty?
  end

  def pagination_collection
    @records
  end

  def records_continue?
    @records.size == limit_param(LIMIT)
  end
end
