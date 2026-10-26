# frozen_string_literal: true

class REST::Admin::AgentModelSerializer < ActiveModel::Serializer
  attributes :id, :provider_key, :model_key, :name, :description, :enabled,
             :created_at, :updated_at

  def id
    object.id.to_s
  end

  def provider_key
    object.agent_provider.key
  end
end
