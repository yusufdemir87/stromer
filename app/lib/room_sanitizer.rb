# frozen_string_literal: true

# Cleans the HTML, SVG and CSS an AI creator writes for its room (see AgentRoom).
#
# A room is shown inside a sandboxed iframe with a Content-Security-Policy that forbids every network
# request (RoomsController), so nothing here can reach the rest of the site. This is the second wall:
# no script, no form, no link that leaves the document, no external picture, no @import. A room can only
# draw, animate, and ask the page around it to open one of a fixed set of drawers (HOOKS).
class RoomSanitizer
  HOOKS = %w(sources works corrections about neighbours follow).freeze
  MAX_BYTES = 60_000
  MAX_NODES = 1_500
  MAX_DEPTH = 40
  MIN_HOOKS = 3

  HTML_ELEMENTS = %w(div span p h1 h2 h3 ul ol li strong em b i br button section figure figcaption title desc style).freeze
  SVG_ELEMENTS = %w(svg g defs symbol use path rect circle ellipse line polyline polygon text tspan lineargradient radialgradient stop clippath mask).freeze

  ATTRIBUTES = %w(
    class id lang role tabindex style data-open aria-label aria-hidden aria-describedby aria-labelledby
    viewbox preserveaspectratio xmlns width height x y x1 y1 x2 y2 cx cy r rx ry fx fy d points transform
    fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-dasharray
    opacity offset stop-color stop-opacity gradientunits gradienttransform clip-path mask href xlink:href
    font-size font-family font-weight text-anchor dominant-baseline letter-spacing
  ).freeze

  CSS_PROPERTIES = %w(
    color background background-color background-image background-size background-position background-repeat
    fill fill-opacity stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-dasharray stroke-dashoffset
    opacity transform transform-origin transform-box filter mix-blend-mode clip-path
    animation animation-name animation-duration animation-delay animation-iteration-count animation-direction
    animation-timing-function animation-fill-mode animation-play-state
    transition transition-property transition-duration transition-timing-function transition-delay
    font font-family font-size font-weight font-style line-height letter-spacing text-align text-transform text-decoration
    text-shadow text-anchor dominant-baseline white-space
    border border-top border-right border-bottom border-left border-color border-width border-style border-radius
    box-shadow outline outline-color outline-offset display position top right bottom left z-index overflow
    width height min-width min-height max-width max-height margin margin-top margin-right margin-bottom margin-left
    padding padding-top padding-right padding-bottom padding-left cursor pointer-events
    flex flex-direction flex-wrap align-items justify-content gap grid grid-template-columns grid-template-rows
    visibility
  ).freeze

  HOOK_VALUE = /\A#{Regexp.union(HOOKS)}\z/
  FRAGMENT = /\A#[A-Za-z][\w-]{0,63}\z/
  FRAGMENT_URL = /\A\s*url\(\s*#[A-Za-z][\w-]{0,63}\s*\)\s*\z/i
  HAZARD = /<\s*(script|iframe|object|embed|form|input|link|meta|base|textarea|select)\b|@import|javascript:|expression\s*\(|\burl\s*\((?!\s*#)|-moz-binding|behavior\s*:/i

  ATTRIBUTE_GUARD = lambda do |env|
    node = env[:node]
    next unless node.element?

    node.attribute_nodes.each do |attribute|
      name = attribute.name.downcase
      value = attribute.value.to_s

      invalid = name.start_with?('on') ||
        (%w(href xlink:href).include?(name) && !value.match?(FRAGMENT)) ||
        (name == 'data-open' && !value.match?(HOOK_VALUE)) ||
        (name == 'tabindex' && value != '0') ||
        (name != 'style' && value.match?(/url\s*\(/i) && !value.match?(FRAGMENT_URL))
      attribute.remove if invalid
    end
  end

  CONFIG = Sanitize::Config.freeze_config(
    elements: HTML_ELEMENTS + SVG_ELEMENTS,
    attributes: { all: ATTRIBUTES },
    protocols: {},
    remove_contents: true,
    css: {
      allow_comments: false,
      allow_hacks: false,
      at_rules_with_styles: %w(keyframes media),
      protocols: [],
      properties: CSS_PROPERTIES,
    },
    transformers: [ATTRIBUTE_GUARD]
  )

  Result = Struct.new(:html, :hooks, :nodes, :problems) do
    def valid?
      problems.empty?
    end
  end

  def self.call(raw)
    new(raw).call
  end

  def initialize(raw)
    @raw = raw.to_s
  end

  def call
    html = Sanitize.fragment(normalized, CONFIG).strip
    html = '' if html.match?(HAZARD)
    fragment = Nokogiri::HTML5.fragment(html)

    Result.new(html, hooks_in(fragment), fragment.css('*').size, problems_for(html, fragment))
  rescue ArgumentError, EncodingError, Nokogiri::SyntaxError
    # Nokogiri refuses documents nested more than a few hundred levels deep; either way it is not a usable room.
    Result.new('', [], 0, ['room could not be read: it is nested too deeply or is not valid text'])
  end

  private

  # Text as it will be stored: valid UTF-8 (anything else is dropped), composed form.
  def normalized
    @raw.dup.force_encoding(Encoding::UTF_8).scrub('').unicode_normalize(:nfc)
  end

  def hooks_in(fragment)
    fragment.css('[data-open]').pluck('data-open').uniq
  end

  def problems_for(html, fragment)
    problems = []
    problems << 'room is empty' if html.blank?
    problems << "room is larger than #{MAX_BYTES} bytes" if html.bytesize > MAX_BYTES
    problems << "room has more than #{MAX_NODES} elements" if fragment.css('*').size > MAX_NODES
    problems << "room is nested more than #{MAX_DEPTH} levels deep" if fragment.css('*').any? { |node| node.ancestors.size > MAX_DEPTH }
    problems << "room needs at least #{MIN_HOOKS} different things to open" if hooks_in(fragment).size < MIN_HOOKS
    problems << 'everything that opens needs an aria-label' if fragment.css('[data-open]').any? { |node| node['aria-label'].to_s.strip.empty? }
    problems
  end
end
