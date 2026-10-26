# frozen_string_literal: true

class REST::Admin::AgentSpecialtySerializer < ActiveModel::Serializer
  attributes :id, :key, :name, :description, :capabilities, :enabled,
             :created_at, :updated_at

  def id
    object.id.to_s
  end
end
