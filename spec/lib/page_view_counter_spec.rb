# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PageViewCounter do
  let(:day) { Date.new(2026, 10, 10) }
  let(:browser) { 'Mozilla/5.0 (X11; Linux x86_64) Firefox/130.0' }

  def visit(ip, page_type: 'account', agent: browser, date: day)
    described_class.record(page_type: page_type, ip: ip, user_agent: agent, now: date.to_time(:utc) + 10.hours)
  end

  def stat(page_type, audience, date: day)
    PageViewStat.find_by(day: date, page_type: page_type, audience: audience)
  end

  describe '.bot?' do
    it 'recognizes crawlers, tools and missing user agents' do
      ['Googlebot/2.1', 'curl/8.0', 'python-requests/2.31', 'Mozilla/5.0 (compatible; bingbot/2.0)', '', nil].each do |agent|
        expect(described_class.bot?(agent)).to be true
      end
    end

    it 'treats ordinary browsers as human' do
      expect(described_class.bot?(browser)).to be false
    end
  end

  describe '.referral_source' do
    it 'keeps only the kind of source, never the address' do
      expect(described_class.referral_source('https://www.google.com/search?q=secret', 'stromer.test')).to eq 'search'
      expect(described_class.referral_source('https://duckduckgo.com/', 'stromer.test')).to eq 'search'
      expect(described_class.referral_source('https://t.co/abc', 'stromer.test')).to eq 'social'
      expect(described_class.referral_source('https://www.reddit.com/r/x', 'stromer.test')).to eq 'social'
      expect(described_class.referral_source('https://blog.example.org/post', 'stromer.test')).to eq 'other'
      expect(described_class.referral_source('https://stromer.test/creators', 'stromer.test')).to eq 'direct'
      expect(described_class.referral_source(nil, 'stromer.test')).to eq 'direct'
      expect(described_class.referral_source('not a url ::', 'stromer.test')).to eq 'other'
    end
  end

  describe 'where visits came from' do
    it 'counts sources beside the pages without adding them to the page totals' do
      described_class.record(page_type: 'account', ip: '203.0.113.1', user_agent: browser, now: day.to_time(:utc) + 10.hours, referer: 'https://www.google.com/', host: 'stromer.test')
      described_class.record(page_type: 'status', ip: '203.0.113.2', user_agent: browser, now: day.to_time(:utc) + 10.hours, referer: 'https://www.google.com/', host: 'stromer.test')
      visit('203.0.113.3')

      described_class.flush(day)

      expect(stat('from_search', 'human').views).to eq 2
      expect(stat('from_direct', 'human').views).to eq 1
      expect(stat('all', 'human').views).to eq 3
    end

    it 'forgets days older than the retention period' do
      PageViewStat.create!(day: day - 500, page_type: 'account', audience: 'human', views: 5)
      PageViewStat.create!(day: day - 10, page_type: 'account', audience: 'human', views: 5)

      described_class.flush(day)

      expect(PageViewStat.where(day: day - 500)).to be_empty
      expect(PageViewStat.where(day: day - 10)).to_not be_empty
    end
  end

  describe 'recording and flushing' do
    it 'counts views per kind of page and audience, and distinct visitors overall' do
      visit('203.0.113.1')
      visit('203.0.113.1', page_type: 'status')
      visit('203.0.113.2')
      visit('198.51.100.9', agent: 'Googlebot/2.1')

      described_class.flush(day)

      expect(stat('account', 'human').views).to eq 2
      expect(stat('status', 'human').views).to eq 1
      expect(stat('account', 'bot').views).to eq 1
      expect(stat('all', 'human')).to have_attributes(views: 3, uniques: 2)
      expect(stat('all', 'bot')).to have_attributes(views: 1, uniques: 1)
    end

    it 'ignores kinds of page it does not know' do
      visit('203.0.113.1', page_type: 'admin')

      described_class.flush(day)

      expect(PageViewStat.where(day: day, audience: 'human').pluck(:page_type)).to eq ['all']
    end

    it 'can be flushed again without double counting' do
      visit('203.0.113.1')

      2.times { described_class.flush(day) }

      expect(PageViewStat.where(day: day, page_type: 'account', audience: 'human').count).to eq 1
      expect(stat('account', 'human').views).to eq 1
    end

    it 'does not keep addresses or user agents in the database' do
      visit('203.0.113.77', agent: 'Firefox/ZZZ-unique')

      described_class.flush(day)

      stored = PageViewStat.all.map(&:attributes).join(' ')
      expect(stored).to_not include('203.0.113.77')
      expect(stored).to_not include('ZZZ-unique')
    end
  end

  describe 'returning visitors' do
    it 'counts visitors already seen earlier in the same month' do
      visit('203.0.113.1', date: day - 2)
      visit('203.0.113.2', date: day - 1)
      visit('203.0.113.1')
      visit('203.0.113.3')

      described_class.flush(day)

      expect(stat('all', 'human')).to have_attributes(uniques: 2, returning: 1)
    end

    it 'does not link a visitor across months' do
      visit('203.0.113.1', date: Date.new(2026, 9, 30))
      visit('203.0.113.1', date: Date.new(2026, 10, 1))

      described_class.flush(Date.new(2026, 10, 1))

      expect(stat('all', 'human', date: Date.new(2026, 10, 1))).to have_attributes(uniques: 1, returning: 0)
    end

    it 'does not count a first-time visitor as returning' do
      visit('203.0.113.1')

      described_class.flush(day)

      expect(stat('all', 'human').returning).to eq 0
    end
  end
end
