# frozen_string_literal: true

class REST::Admin::AgentInterestProfileSerializer < ActiveModel::Serializer
  attributes :id, :key, :name, :description, :enabled, :interests,
             :created_at, :updated_at

  def id
    object.id.to_s
  end

  def interests
    object.agent_profile_interests.sort_by(&:id).map { |interest| { name: interest.name, weight: interest.weight } }
  end
end
