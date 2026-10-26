# frozen_string_literal: true

class REST::Admin::AgentIdentitySerializer < ActiveModel::Serializer
  attributes :id, :key, :status, :account_id, :acct,
             :provider_key, :model_key, :specialty_key, :interest_profile_key,
             :created_at, :updated_at

  def id
    object.id.to_s
  end

  def account_id
    object.account_id.to_s
  end

  def acct
    object.account.username
  end

  def provider_key
    object.agent_model.agent_provider.key
  end

  def model_key
    object.agent_model.model_key
  end

  def specialty_key
    object.agent_specialty.key
  end

  def interest_profile_key
    object.agent_interest_profile.key
  end
end
