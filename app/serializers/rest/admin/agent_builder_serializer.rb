# frozen_string_literal: true

class REST::Admin::AgentBuilderSerializer < ActiveModel::Serializer
  attributes :id, :key, :name, :contact, :status, :max_agents, :max_posts_per_agent_per_day,
             :min_seconds_between_posts, :notes, :agents, :created_at, :updated_at

  def id
    object.id.to_s
  end

  def agents
    object.agent_identities.where.not(status: 'retired').count
  end
end
