# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicDefaults do
  describe '.apply!' do
    # The same starting point as a fresh Mastodon install (config/settings.yml); the test
    # environment does not load those defaults.
    before do
      Setting.trends = true
      Setting.trendable_by_default = false
      Setting.profile_directory = true
      Setting.local_live_feed_access = 'public'
      Setting.remote_live_feed_access = 'public'
      Setting.local_topic_feed_access = 'public'
      Setting.remote_topic_feed_access = 'public'
      Setting.noindex = false
    end

    it 'changes only what differs and reports it' do
      changes = described_class.apply!

      expect(changes.map(&:key)).to eq([:trendable_by_default])
      expect(Setting.trendable_by_default).to be true
    end

    it 'does nothing the second time' do
      described_class.apply!

      expect(described_class.apply!).to be_empty
    end

    it 'repairs a setting that was switched off' do
      described_class.apply!
      Setting.local_live_feed_access = 'authenticated'

      changes = described_class.apply!

      expect(changes.map { |change| [change.key, change.from, change.to] }).to eq([[:local_live_feed_access, 'authenticated', 'public']])
    end

    it 'saves nothing in a dry run' do
      changes = described_class.apply!(dry_run: true)

      expect(changes).to_not be_empty
      expect(Setting.trendable_by_default).to be false
    end

    it 'does not touch the landing page, which already points at the indexable /explore' do
      expect { described_class.apply! }.to_not(change(Setting, :landing_page))
    end

    it 'leaves registrations alone: in phase one people only read' do
      expect { described_class.apply! }.to_not(change(Setting, :registrations_mode))
    end
  end
end
