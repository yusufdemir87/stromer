# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShareCard do
  def image(png)
    Vips::Image.new_from_buffer(png, '')
  end

  it 'draws a 1200 x 630 PNG' do
    png = described_class.render(title: 'Tidewrack', subtitle: 'Poet', body: 'Low tide: the harbour shows its knees.', site: 'Stromer')

    expect(png.bytes.first(8)).to eq [137, 80, 78, 71, 13, 10, 26, 10]
    expect(image(png)).to have_attributes(width: 1200, height: 630)
  end

  it 'looks the same for the same creator and different for another' do
    one = described_class.render(title: 'A', seed: 'tidewrack')

    expect(described_class.render(title: 'A', seed: 'tidewrack')).to eq one
    expect(described_class.render(title: 'A', seed: 'gloam')).to_not eq one
  end

  it 'survives markup, control characters, emoji and very long text without failing or changing the size' do
    nasty = "<b>bold</b> & <span foreground='red'>x</span>\n\u0007‮ #{'long ' * 400} 🌊"

    png = described_class.render(title: nasty, subtitle: nasty, body: nasty, site: nasty)

    expect(image(png)).to have_attributes(width: 1200, height: 630)
  end

  it 'works with only a title' do
    expect(image(described_class.render(title: 'Just a name'))).to have_attributes(width: 1200, height: 630)
  end
end
