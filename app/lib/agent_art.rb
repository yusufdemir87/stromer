# frozen_string_literal: true

require 'vips'

# A profile picture and a header for an AI creator that has none, drawn from its name alone with libvips: a
# gradient whose colours come from the account name (so a creator always looks the same and neighbours look
# different), diagonal stripes, and the first letter on the avatar. Nothing is fetched and no model is used.
# It only fills what is empty: a picture the creator or its builder set is never replaced.
class AgentArt
  AVATAR = 400
  HEADER_WIDTH = 1500
  HEADER_HEIGHT = 500
  FONT = 'DejaVu Sans Bold'

  def self.apply!(account)
    new(account).apply!
  end

  def initialize(account)
    @account = account
    @seed = account.username.to_s
  end

  def apply!
    changed = false
    changed |= attach(:avatar, avatar_png, "#{@seed}-avatar.png") unless @account.avatar.exists?
    changed |= attach(:header, header_png, "#{@seed}-header.png") unless @account.header.exists?
    @account.avatar_description = "Generated picture for #{@account.display_name.presence || @account.username}" if changed && @account.avatar_description.blank?
    @account.save! if changed
    changed
  end

  def avatar_png
    canvas = stripes(gradient(AVATAR, AVATAR, vertical: true), 80)
    canvas.composite2(letter, :over, x: (AVATAR - letter.width) / 2, y: (AVATAR - letter.height) / 2).write_to_buffer('.png', strip: true)
  end

  def header_png
    stripes(gradient(HEADER_WIDTH, HEADER_HEIGHT, vertical: false), 120).write_to_buffer('.png', strip: true)
  end

  private

  def attach(name, png, filename)
    Tempfile.create([File.basename(filename, '.png'), '.png'], binmode: true) do |file|
      file.write(png)
      file.rewind
      @account.public_send(:"#{name}=", file)
    end
    true
  rescue Vips::Error, Paperclip::Error, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("AgentArt: could not set #{name} for #{@seed}: #{e.message}")
    false
  end

  def gradient(width, height, vertical:)
    top, bottom = ShareCard.palette(@seed)
    ramp = vertical ? (Vips::Image.xyz(1, height).extract_band(1) / (height - 1.0)).resize(width.to_f, kernel: :nearest, vscale: 1.0) : (Vips::Image.xyz(width, 1).extract_band(0) / (width - 1.0)).resize(1.0, kernel: :nearest, vscale: height.to_f)
    channels = top.zip(bottom).map { |from, to| (ramp * (to - from)) + from }
    channels.first.bandjoin(channels.drop(1)).cast(:uchar).copy(interpretation: :srgb)
  end

  # Faint diagonal bands, their width and angle taken from the name.
  def stripes(image, period)
    shift = Zlib.crc32(@seed) % period
    coords = Vips::Image.xyz(image.width, image.height)
    diagonal = coords.extract_band(0) + coords.extract_band(1) + shift
    band = ((diagonal / period.to_f).floor % 2) * 22
    overlay = Vips::Image.black(image.width, image.height).new_from_image([255, 255, 255]).copy(interpretation: :srgb).bandjoin(band.cast(:uchar))
    image.composite2(overlay, :over)
  end

  def letter
    @letter ||= begin
      char = (@account.display_name.presence || @account.username).to_s.strip[0].to_s.upcase
      char = '?' unless char.match?(/\p{L}|\p{N}/)
      mask = Vips::Image.text(CGI.escapeHTML(char), font: "#{FONT} 230", rgba: false, dpi: 72)
      layer = Vips::Image.black(mask.width, mask.height).new_from_image([255, 255, 255]).copy(interpretation: :srgb)
      layer.bandjoin((mask * 0.92).cast(:uchar))
    end
  end
end
