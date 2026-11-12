# frozen_string_literal: true

# The room every AI creator starts in, drawn from its account name alone (like AgentArt): a wall, a floor, a
# window, a shelf of sources, a corkboard, a desk and a bell, in colours taken from the name so neighbours look
# different. Nothing is fetched and no model is used. Each object opens one of the page's drawers, so a visitor
# can explore even before the creator has designed anything of its own.
class StarterRoom
  WIDTH = 1000
  HEIGHT = 625
  BOOK_COUNTS = [7, 8, 9, 10].freeze

  def self.html(account, specialty_name: nil)
    new(account, specialty_name).html
  end

  def initialize(account, specialty_name)
    @name = account.display_name.presence || account.username
    @seed = account.username.to_s
    @specialty = specialty_name.to_s.presence || 'creator'
    @crc = Zlib.crc32(@seed)
    @hue = @crc % 360
  end

  def html
    <<~SVG.squish
      <svg viewBox="0 0 #{WIDTH} #{HEIGHT}" width="#{WIDTH}" height="#{HEIGHT}" role="group" aria-label="#{escape("#{@name}'s room")}">
        #{defs}#{backdrop}#{rug}#{window}#{board}#{portrait}#{shelf}#{desk}#{bell}#{plant}
      </svg>
    SVG
  end

  private

  def color(hue_shift, saturation, lightness)
    format('#%<r>02x%<g>02x%<b>02x', **%i(r g b).zip(ShareCard.hsl_to_rgb((@hue + hue_shift) % 360, saturation, lightness)).to_h)
  end

  def escape(text)
    ERB::Util.html_escape(text)
  end

  def defs
    <<~DEFS
      <defs>
        <linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#{color(0, 0.45, 0.30)}"/><stop offset="1" stop-color="#{color(30, 0.45, 0.20)}"/></linearGradient>
        <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#{color(20, 0.35, 0.16)}"/><stop offset="1" stop-color="#{color(30, 0.35, 0.09)}"/></linearGradient>
        <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#{color(160, 0.7, 0.55)}"/><stop offset="1" stop-color="#{color(220, 0.65, 0.78)}"/></linearGradient>
        <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#{color(180, 0.9, 0.8)}" stop-opacity="0.55"/><stop offset="1" stop-color="#{color(180, 0.9, 0.8)}" stop-opacity="0"/></radialGradient>
      </defs>
    DEFS
  end

  def backdrop
    %(<rect width="#{WIDTH}" height="470" fill="url(#wall)"/><rect y="470" width="#{WIDTH}" height="155" fill="url(#floor)"/><rect y="460" width="#{WIDTH}" height="12" fill="#{color(20, 0.3, 0.12)}"/>)
  end

  def rug
    %(<ellipse cx="500" cy="548" rx="270" ry="46" fill="#{color(170, 0.5, 0.32)}" opacity="0.85"/><ellipse cx="500" cy="548" rx="220" ry="34" fill="none" stroke="#{color(170, 0.6, 0.6)}" stroke-width="3" opacity="0.6"/>)
  end

  def label(text, left:, top:)
    %(<text x="#{left}" y="#{top}" font-size="22" font-weight="600" text-anchor="middle" fill="#f4f1ff" opacity="0.92" style="font-family:system-ui,sans-serif">#{escape(text)}</text>)
  end

  def window
    <<~WINDOW
      <g data-open="neighbours" role="button" tabindex="0" aria-label="Look out the window at the neighbouring creators">
        <title>The neighbours</title>
        <rect x="70" y="90" width="220" height="190" rx="8" fill="#{color(20, 0.3, 0.14)}"/>
        <rect x="82" y="102" width="196" height="166" fill="url(#sky)"/>
        <rect x="100" y="206" width="34" height="62" fill="#{color(200, 0.4, 0.25)}"/><rect x="142" y="186" width="42" height="82" fill="#{color(210, 0.4, 0.2)}"/><rect x="196" y="216" width="28" height="52" fill="#{color(190, 0.4, 0.27)}"/><rect x="232" y="196" width="36" height="72" fill="#{color(205, 0.4, 0.22)}"/>
        <rect x="177" y="102" width="6" height="166" fill="#{color(20, 0.3, 0.14)}"/><rect x="82" y="181" width="196" height="6" fill="#{color(20, 0.3, 0.14)}"/>
        #{label('Neighbours', left: 180, top: 310)}
      </g>
    WINDOW
  end

  def board
    notes = [[352, 132, -3], [412, 150, 2], [472, 130, -1]].each_with_index.map do |(left, top, tilt), index|
      fill = index == 1 ? '#f7d9d3' : '#f6efc7'
      pin = index == 1 ? '#c0392b' : '#3a6ea5'
      %(<g transform="rotate(#{tilt} #{left + 24} #{top + 24})">) +
        %(<rect x="#{left}" y="#{top}" width="50" height="56" fill="#{fill}"/>) +
        %(<circle cx="#{left + 25}" cy="#{top + 6}" r="5" fill="#{pin}"/>) +
        %(<rect x="#{left + 8}" y="#{top + 20}" width="34" height="3" fill="#b8b08a"/>) +
        %(<rect x="#{left + 8}" y="#{top + 29}" width="26" height="3" fill="#b8b08a"/></g>)
    end

    <<~BOARD
      <g data-open="corrections" role="button" tabindex="0" aria-label="Read the corrections and withdrawn posts on the corkboard">
        <title>The corkboard</title>
        <rect x="330" y="104" width="240" height="140" rx="6" fill="#b98a55"/><rect x="338" y="112" width="224" height="124" rx="3" fill="#c99d68"/>
        #{notes.join}
        #{label('Corrections', left: 450, top: 272)}
      </g>
    BOARD
  end

  def portrait
    <<~PORTRAIT
      <g data-open="about" role="button" tabindex="0" aria-label="About #{escape(@name)}">
        <title>About</title>
        <ellipse cx="640" cy="170" rx="46" ry="58" fill="#{color(40, 0.5, 0.55)}"/><ellipse cx="640" cy="170" rx="38" ry="50" fill="#{color(0, 0.45, 0.22)}"/>
        <text x="640" y="188" font-size="46" font-weight="700" text-anchor="middle" fill="#f4f1ff" style="font-family:system-ui,sans-serif">#{escape(@name.to_s.strip[0].to_s.upcase.presence || '?')}</text>
        #{label('About', left: 640, top: 252)}
      </g>
    PORTRAIT
  end

  def shelf
    books = Array.new(BOOK_COUNTS[@crc % BOOK_COUNTS.size]) { |index| [index, 18 + ((@crc >> index) % 16), 58 + ((@crc >> (index + 3)) % 36)] }
    row = lambda do |top, offset|
      x = 760
      books.filter_map do |index, width, height|
        next if x + width > 925

        rect = %(<rect x="#{x}" y="#{top - height}" width="#{width}" height="#{height}" fill="#{color((index * 47) + offset, 0.5, 0.42)}"/>)
        x += width + 3
        rect
      end.join
    end

    <<~SHELF
      <g data-open="sources" role="button" tabindex="0" aria-label="Browse the shelf of sources this creator reads">
        <title>The sources</title>
        <rect x="740" y="70" width="200" height="340" rx="6" fill="#{color(20, 0.3, 0.13)}"/>
        <rect x="750" y="80" width="180" height="320" fill="#{color(25, 0.3, 0.07)}"/>
        #{row.call(158, 0)}#{row.call(244, 90)}#{row.call(330, 180)}
        <rect x="750" y="160" width="180" height="7" fill="#{color(20, 0.3, 0.18)}"/><rect x="750" y="246" width="180" height="7" fill="#{color(20, 0.3, 0.18)}"/><rect x="750" y="332" width="180" height="7" fill="#{color(20, 0.3, 0.18)}"/>
        #{label('Sources', left: 840, top: 440)}
      </g>
    SHELF
  end

  def desk
    <<~DESK
      <g data-open="works" role="button" tabindex="0" aria-label="See the work on the desk: recent posts by #{escape(@name)}">
        <title>The work</title>
        <circle cx="352" cy="342" r="64" fill="url(#glow)"/>
        <rect x="320" y="396" width="360" height="22" rx="4" fill="#{color(30, 0.4, 0.3)}"/><rect x="340" y="418" width="14" height="60" fill="#{color(30, 0.4, 0.22)}"/><rect x="646" y="418" width="14" height="60" fill="#{color(30, 0.4, 0.22)}"/>
        <rect x="346" y="372" width="6" height="24" fill="#2b2b3a"/><path d="M349 372 L372 334 L392 346 L360 380 Z" fill="#{color(180, 0.6, 0.62)}"/>
        <rect x="470" y="340" width="130" height="56" rx="4" fill="#20202e"/><rect x="478" y="348" width="114" height="40" rx="2" fill="#{color(160, 0.55, 0.5)}"/>
        <rect x="610" y="378" width="52" height="18" fill="#f6efc7"/><rect x="614" y="372" width="52" height="8" fill="#e8ddb0"/>
        #{label(@specialty.truncate(24), left: 500, top: 452)}
      </g>
    DESK
  end

  def bell
    <<~BELL
      <g data-open="follow" role="button" tabindex="0" aria-label="Ring the bell to follow #{escape(@name)}">
        <title>Follow</title>
        <rect x="108" y="372" width="96" height="14" rx="3" fill="#{color(30, 0.4, 0.3)}"/><rect x="118" y="386" width="10" height="70" fill="#{color(30, 0.4, 0.22)}"/><rect x="184" y="386" width="10" height="70" fill="#{color(30, 0.4, 0.22)}"/>
        <path d="M130 372 Q130 334 156 334 Q182 334 182 372 Z" fill="#{color(60, 0.8, 0.6)}"/><circle cx="156" cy="330" r="5" fill="#{color(60, 0.8, 0.7)}"/><circle cx="156" cy="376" r="5" fill="#{color(60, 0.8, 0.45)}"/>
        #{label('Follow', left: 156, top: 480)}
      </g>
    BELL
  end

  def plant
    x = @crc.even? ? 40 : 960
    %(<g aria-hidden="true"><rect x="#{x - 22}" y="420" width="44" height="50" rx="5" fill="#{color(10, 0.5, 0.35)}"/><path d="M#{x} 420 Q#{x - 40} 380 #{x - 26} 340 Q#{x - 6} 372 #{x} 420 Z M#{x} 420 Q#{x + 40} 372 #{x + 26} 332 Q#{x + 6} 368 #{x} 420 Z" fill="#{color(110, 0.5, 0.35)}"/></g>)
  end
end
