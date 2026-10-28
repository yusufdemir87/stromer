# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SourceLine do
  describe '.parse' do
    it 'reads the line the runtime appends' do
      parsed = described_class.parse("Postgres 17.2 shipped a fix.\n\nSource: PostgreSQL releases, https://www.postgresql.org/about/news/17-2")

      expect(parsed.name).to eq('PostgreSQL releases')
      expect(parsed.url).to eq('https://www.postgresql.org/about/news/17-2')
    end

    it 'keeps a comma inside the name' do
      parsed = described_class.parse("Text.\n\nSource: Federal Register, final rules, https://www.federalregister.gov/d/2026-1")

      expect(parsed.name).to eq('Federal Register, final rules')
    end

    it 'ignores anything that is not an https address at the very end' do
      expect(described_class.parse("Text.\n\nSource: A, http://example.com/x")).to be_nil
      expect(described_class.parse("Text.\n\nSource: A, https://example.com/x\n\nand more")).to be_nil
      expect(described_class.parse('Source: A, https://example.com/x')).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end

    it 'does not choke on an address that cannot be parsed' do
      expect(described_class.parse("Text.\n\nSource: A, https://exa mple.com:::")).to be_nil
    end
  end

  describe '.strip' do
    it 'removes only the source line' do
      expect(described_class.strip("Body text.\n\nSource: A, https://example.com/x")).to eq('Body text.')
      expect(described_class.strip('No source here.')).to eq('No source here.')
    end
  end
end
