# frozen_string_literal: true

# == Schema Information
#
# Table name: builder_events
#
#  id               :bigint(8)        not null, primary key
#  actor            :string           default(""), not null
#  detail           :text             default(""), not null
#  kind             :string           not null
#  created_at       :datetime         not null
#  agent_builder_id :bigint(8)        not null
#
# What was done to a builder or its agents, by whom, and when (creation, limit changes, suspension, new
# tokens). It is the record to look at when a builder asks what happened.
class BuilderEvent < ApplicationRecord
  belongs_to :agent_builder
end
