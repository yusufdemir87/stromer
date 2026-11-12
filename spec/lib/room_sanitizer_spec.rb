# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoomSanitizer do
  def room(body)
    <<~HTML
      <svg viewBox="0 0 100 100" role="group" aria-label="Room">
        <g data-open="sources" role="button" tabindex="0" aria-label="Sources"><rect width="10" height="10"/></g>
        <g data-open="works" role="button" tabindex="0" aria-label="Works"><rect width="10" height="10"/></g>
        <g data-open="about" role="button" tabindex="0" aria-label="About"><rect width="10" height="10"/></g>
        #{body}
      </svg>
    HTML
  end

  def clean(body)
    described_class.call(room(body))
  end

  it 'keeps drawing, gradients and the hooks, with their case' do
    result = clean('<defs><linearGradient id="g"><stop offset="0" stop-color="#fff"/></linearGradient></defs><rect fill="url(#g)" width="5" height="5"/><text x="1" y="2" font-size="9">Hi</text>')

    expect(result).to be_valid
    expect(result.html).to include('viewBox="0 0 100 100"', '<linearGradient id="g">', 'fill="url(#g)"', 'data-open="sources"', '<text')
    expect(result.hooks).to contain_exactly('sources', 'works', 'about')
  end

  it 'drops scripts and everything they carry' do
    html = clean('<script>alert(1)</script><rect onclick="alert(2)" width="1" height="1"/><iframe src="https://evil.example"></iframe>').html

    expect(html).to_not match(/script|alert|onclick|iframe|evil/i)
  end

  it 'drops forms, inputs, links, meta and base' do
    html = clean('<form action="https://evil.example"><input name="password"></form><a href="https://evil.example">x</a><meta http-equiv="refresh" content="0;url=https://evil.example"><base href="https://evil.example">').html

    expect(html).to_not match(/form|input|evil|<a |meta|base/i)
  end

  it 'allows a reference only to something in the same drawing' do
    html = clean('<use href="https://evil.example/s.svg#x"/><use href="#chair"/><use xlink:href="javascript:alert(1)"/>').html

    expect(html).to_not match(/evil|javascript/i)
    expect(html).to include('href="#chair"')
  end

  it 'drops external pictures and other url() values from attributes' do
    html = clean('<rect fill="url(https://evil.example/a.png)" width="1" height="1"/><rect clip-path="url(data:image/svg+xml;base64,AAAA)" width="1" height="1"/>').html

    expect(html).to_not match(/evil|base64|url\(h|url\(d/i)
  end

  it 'cleans style sheets: no imports, no external url(), no behaviours' do
    html = clean('<style>@import url("https://evil.example/x.css"); rect{fill:red; background:url(https://evil.example/a.png); behavior:url(x.htc); width:10px}</style>').html

    expect(html).to_not match(/@import|evil|behavior|htc/i)
    expect(html).to include('fill')
  end

  it 'cleans style attributes' do
    html = clean('<rect style="fill:red; background-image:url(https://evil.example/a.png); position:fixed" width="1" height="1"/>').html

    expect(html).to_not match(/evil|url\(/i)
    expect(html).to include('fill')
  end

  it 'keeps animations that a visitor can switch off' do
    html = clean('<style>@keyframes bob{from{transform:translateY(0)}to{transform:translateY(4px)}} rect{animation:bob 2s infinite}</style>').html

    expect(html).to include('keyframes', 'animation')
  end

  it 'ignores hooks that are not on the list and tab stops other than 0' do
    html = clean('<g data-open="logout" tabindex="5" aria-label="x"><rect width="1" height="1"/></g>').html

    expect(html).to_not include('logout')
    expect(html).to_not include('tabindex="5"')
  end

  it 'refuses a room with fewer than three different things to open' do
    result = described_class.call('<svg viewBox="0 0 1 1"><g data-open="sources" aria-label="Sources"><rect width="1" height="1"/></g></svg>')

    expect(result).to_not be_valid
    expect(result.problems).to include(/at least 3/)
  end

  it 'refuses things to open that have no aria-label' do
    result = described_class.call(room('<g data-open="follow"><rect width="1" height="1"/></g>'))

    expect(result.problems).to include(/aria-label/)
  end

  it 'refuses a room that is too large or has too many elements' do
    big = described_class.call(room("<text>#{'a' * 61_000}</text>"))
    many = described_class.call(room('<rect width="1" height="1"/>' * 1_600))

    expect(big.problems).to include(/larger than/)
    expect(many.problems).to include(/more than/)
  end

  it 'blanks everything that still looks dangerous after cleaning' do
    expect(described_class.call('<svg><text>@import "x"</text></svg>').html).to be_empty
  end
end
