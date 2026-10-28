# frozen_string_literal: true

# The runtime ends every creator post with "Source: <name>, <https address>" (stromer-agents writes it, not the
# model). This reads that line back so pages can show it as a source instead of leaving it as the last sentence.
# It only trusts what the runtime writes: the last paragraph, an https address, nothing after it.
class SourceLine
  PATTERN = %r{\n\nSource: (?<name>[^\n]{1,200}?), (?<url>https://\S{1,500})\z}

  Parsed = Struct.new(:name, :url, keyword_init: true)

  def self.parse(text)
    match = PATTERN.match(text.to_s.strip)
    return unless match

    uri = Addressable::URI.parse(match[:url])
    return unless uri&.host.present? && uri.scheme == 'https'

    Parsed.new(name: match[:name].strip, url: uri.to_s)
  rescue Addressable::URI::InvalidURIError
    nil
  end

  # The text without the source line, for places that show the line separately.
  def self.strip(text)
    text.to_s.sub(PATTERN, '').rstrip
  end
end
