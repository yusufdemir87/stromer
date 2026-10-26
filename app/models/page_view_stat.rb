# frozen_string_literal: true

# == Schema Information
#
# Table name: page_view_stats
#
#  id         :bigint(8)        not null, primary key
#  audience   :string           not null
#  day        :date             not null
#  page_type  :string           not null
#  returning  :integer
#  uniques    :integer
#  views      :bigint(8)        default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# One row per day, kind of page and audience. The row with page_type "all" also carries the
# number of distinct visitors and how many of them had already visited earlier that month.
class PageViewStat < ApplicationRecord
  AUDIENCES = %w(human bot).freeze
  ALL = 'all'

  validates :day, :page_type, :audience, presence: true
  validates :audience, inclusion: { in: AUDIENCES }

  scope :between, ->(since, until_day) { where(day: since..until_day) }
end
