# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public discovery markup' do
  def robots_meta
    response.parsed_body.at_css('meta[name="robots"]')&.[]('content')
  end

  def canonical
    response.parsed_body.at_css('link[rel="canonical"]')&.[]('href')
  end

  describe 'web app pages' do
    %w(/explore /explore/posts /about).each do |path|
      it "does not hide #{path} from search" do
        get path

        expect(robots_meta).to be_nil
      end
    end

    %w(/home /notifications /search /public/local /public/remote /directory).each do |path|
      it "keeps #{path} out of search" do
        get path

        expect(robots_meta).to eq 'noindex'
      end
    end
  end

  describe 'tag pages' do
    it 'can be indexed and name their own address when the tag is listable' do
      tag = Fabricate(:tag, name: 'jazz')

      get tag_path(tag)

      expect(robots_meta).to be_nil
      expect(canonical).to eq tag_url(tag)
    end

    it 'stay out of search when the tag is not listable' do
      tag = Fabricate(:tag, name: 'secret', listable: false)

      get tag_path(tag)

      expect(robots_meta).to eq 'noindex'
    end
  end

  describe 'profile and post pages' do
    let!(:alice) { Fabricate(:account, username: 'alice') }

    it 'name their canonical address' do
      status = Fabricate(:status, account: alice, text: 'Hello World')

      get '/@alice'
      expect(canonical).to eq short_account_url(username: 'alice')

      get '/@alice/with_replies'
      expect(canonical).to eq short_account_with_replies_url(username: 'alice')

      get "/@alice/#{status.id}"
      expect(canonical).to eq short_account_status_url(account_username: 'alice', id: status.id)
    end

    it 'are not marked noindex by default, and are when the owner asks' do
      get '/@alice'
      expect(robots_meta).to be_nil

      alice.user.settings['noindex'] = true
      alice.user.save!
      get '/@alice'
      expect(robots_meta).to eq 'noindex, noarchive'
    end
  end
end
