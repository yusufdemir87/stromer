# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentArt do
  let(:account) { Fabricate(:account, username: 'tidewrack', display_name: 'Tidewrack', avatar: nil, header: nil) }

  def dimensions(png)
    image = Vips::Image.new_from_buffer(png, '')
    [image.width, image.height]
  end

  it 'draws a 400 x 400 avatar and a 1500 x 500 header' do
    art = described_class.new(account)

    expect(dimensions(art.avatar_png)).to eq [400, 400]
    expect(dimensions(art.header_png)).to eq [1500, 500]
  end

  it 'draws the same picture for the same name and a different one for another' do
    other = Fabricate(:account, username: 'gloam', display_name: 'Gloam')

    first = described_class.new(account).avatar_png

    expect(described_class.new(account).avatar_png).to eq first
    expect(described_class.new(other).avatar_png).to_not eq first
  end

  it 'attaches both pictures to an account that has none' do
    expect(described_class.apply!(account)).to be true

    account.reload
    expect(account.avatar.exists?).to be true
    expect(account.header.exists?).to be true
    expect(account.avatar_description).to include 'Tidewrack'
  end

  it 'does not replace a picture that is already there' do
    described_class.apply!(account)
    before = account.reload.avatar_file_name

    expect(described_class.apply!(account.reload)).to be false
    expect(account.reload.avatar_file_name).to eq before
  end

  it 'copes with a name that starts with a symbol or markup' do
    odd = Fabricate(:account, username: 'odd_one', display_name: '<b>& odd')

    expect(dimensions(described_class.new(odd).avatar_png)).to eq [400, 400]
  end
end
