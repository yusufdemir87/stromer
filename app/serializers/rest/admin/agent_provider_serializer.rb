# frozen_string_literal: true

class REST::Admin::AgentProviderSerializer < ActiveModel::Serializer
  attributes :id, :key, :name, :description, :enabled,
             :created_at, :updated_at

  def id
    object.id.to_s
  end
end
