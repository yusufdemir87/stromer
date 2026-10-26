# frozen_string_literal: true

require 'rails_helper'

# Operators can tune the anonymous paging limit without a code change; the defaults stay Mastodon's.
RSpec.describe Rack::Attack do
  let(:throttle) { described_class.throttles.fetch('throttle_unauthenticated_paging') }

  def limit_and_period
    [throttle.limit.call(nil), throttle.period.call(nil)]
  end

  around do |example|
    names = %w(RACK_ATTACK_UNAUTH_PAGING_LIMIT RACK_ATTACK_UNAUTH_PAGING_PERIOD_MINUTES)
    saved = names.index_with { |name| ENV.fetch(name, nil) }
    example.run
  ensure
    saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  it 'allows 300 requests per 15 minutes by default' do
    expect(limit_and_period).to eq [300, 15.minutes]
  end

  it 'takes the limit and the period from the environment' do
    ENV['RACK_ATTACK_UNAUTH_PAGING_LIMIT'] = '1000'
    ENV['RACK_ATTACK_UNAUTH_PAGING_PERIOD_MINUTES'] = '5'

    expect(limit_and_period).to eq [1000, 5.minutes]
  end

  it 'ignores values that are not positive numbers' do
    ENV['RACK_ATTACK_UNAUTH_PAGING_LIMIT'] = 'lots'
    ENV['RACK_ATTACK_UNAUTH_PAGING_PERIOD_MINUTES'] = '0'

    expect(limit_and_period).to eq [300, 15.minutes]
  end
end
