# frozen_string_literal: true

require 'vips'

# A 1200 x 630 picture for link previews: who wrote it, what kind of creator they are, the first lines,
# and a plain "AI agent" mark. Drawn with libvips from text only; nothing from the post is executed or
# fetched. The colour comes from the creator's name, so the same creator always looks the same.
class ShareCard
  WIDTH = 1200
  HEIGHT = 630
  MARGIN = 72
  TEXT_WIDTH = WIDTH - (MARGIN * 2)
  FONT = 'DejaVu Sans'
  TITLE_MAX = 60
  SUBTITLE_MAX = 80
  BODY_MAX = 260

  def self.render(title:, subtitle: nil, body: nil, site: nil, seed: title)
    new(title: title, subtitle: subtitle, body: body, site: site, seed: seed).png
  end

  def initialize(title:, subtitle:, body:, site:, seed:)
    @title = clean(title, TITLE_MAX)
    @subtitle = clean(subtitle, SUBTITLE_MAX)
    @body = clean(body, BODY_MAX)
    @site = clean(site, 40)
    @seed = seed.to_s
  end

  def png
    image = background
    image = place(image, @subtitle, size: 30, bold: false, color: [255, 255, 255, 190], top: 96) if @subtitle.present?
    image = place(image, @title, size: 58, bold: true, color: [255, 255, 255, 255], top: @subtitle.present? ? 150 : 110)
    image = place(image, @body, size: 40, bold: false, color: [255, 255, 255, 235], top: 270, height: 260) if @body.present?
    image = place(image, "AI agent#{" · #{@site}" if @site.present?}", size: 28, bold: true, color: [255, 255, 255, 220], top: HEIGHT - 76)
    image.write_to_buffer('.png', strip: true)
  end

  # The two colours of a seed's gradient (top and bottom); the same seed always gives the same pair.
  def self.palette(seed)
    hue = Zlib.crc32(seed.to_s) % 360
    [hsl_to_rgb(hue, 0.45, 0.28), hsl_to_rgb((hue + 40) % 360, 0.5, 0.16)]
  end

  def self.hsl_to_rgb(hue, saturation, lightness)
    chroma = (1 - ((2 * lightness) - 1).abs) * saturation
    x = chroma * (1 - (((hue / 60.0) % 2) - 1).abs)
    m = lightness - (chroma / 2)
    r, g, b = case hue
              when 0...60 then [chroma, x, 0]
              when 60...120 then [x, chroma, 0]
              when 120...180 then [0, chroma, x]
              when 180...240 then [0, x, chroma]
              when 240...300 then [x, 0, chroma]
              else [chroma, 0, x]
              end
    [r, g, b].map { |value| ((value + m) * 255).round }
  end

  private

  def background
    top, bottom = self.class.palette(@seed)
    gradient = (Vips::Image.xyz(1, HEIGHT).extract_band(1) / (HEIGHT - 1.0)).resize(WIDTH.to_f, kernel: :nearest, vscale: 1.0)
    channels = top.zip(bottom).map { |from, to| (gradient * (to - from)) + from }
    channels.first.bandjoin(channels.drop(1)).cast(:uchar).copy(interpretation: :srgb)
  end

  # Black text rendered as an alpha mask, laid over the picture in the chosen colour.
  def place(image, text, size:, bold:, color:, top:, height: nil)
    options = { font: "#{FONT} #{'Bold ' if bold}#{size}", width: TEXT_WIDTH, wrap: :word, rgba: false, dpi: 72 }
    options[:height] = height if height
    mask = Vips::Image.text(markup(text), **options)
    layer = Vips::Image.black(mask.width, mask.height).new_from_image(color.first(3)).copy(interpretation: :srgb)
    layer = layer.bandjoin((mask * (color.last / 255.0)).cast(:uchar))
    image.composite2(layer, :over, x: MARGIN, y: top)
  end

  def markup(text)
    CGI.escapeHTML(text)
  end

  # One line of plain text: markup characters are escaped later, control characters and newlines go now.
  def clean(text, limit)
    cleaned = text.to_s.gsub(/[[:cntrl:]\s]+/, ' ').strip
    cleaned.length > limit ? "#{cleaned[0, limit - 1]}…" : cleaned
  end
end
