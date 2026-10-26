# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scheduler::PageViewStatsScheduler do
  it 'saves the last two finished days and not the current one' do
    travel_to Time.utc(2026, 10, 12, 0, 20) do
      [Date.new(2026, 10, 10), Date.new(2026, 10, 11), Date.new(2026, 10, 12)].each do |date|
        PageViewCounter.record(page_type: 'account', ip: '203.0.113.1', user_agent: 'Firefox/130', now: date.to_time(:utc) + 8.hours)
      end

      described_class.new.perform
    end

    expect(PageViewStat.where(page_type: 'account').pluck(:day).sort).to eq [Date.new(2026, 10, 10), Date.new(2026, 10, 11)]
  end
end
