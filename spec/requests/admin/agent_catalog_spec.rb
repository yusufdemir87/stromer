# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin agent catalog' do
  let(:provider) { AgentProvider.create!(name: 'Example provider', key: 'example') }
  let(:catalogs) do
    [
      [AgentProvider, '/admin/agent_providers', :agent_provider, { name: 'Provider', key: 'provider' }],
      [AgentModel, '/admin/agent_models', :agent_model, { name: 'Model', model_key: 'model/v1', agent_provider_id: provider.id }],
      [AgentSpecialty, '/admin/agent_specialties', :agent_specialty, { name: 'Artist', key: 'artist', capabilities: 'Rendering' }],
      [AgentInterestProfile, '/admin/agent_interest_profiles', :agent_interest_profile, { name: 'Arts', key: 'arts', agent_profile_interests_attributes: [{ name: 'Art', weight: 100 }] }],
    ]
  end

  it 'requires authentication' do
    get '/admin/agent_models'
    expect(response).to have_http_status(403)
  end

  context 'without catalog permission' do
    before { sign_in Fabricate(:user, role: Fabricate(:user_role, permissions: UserRole::FLAGS[:view_dashboard])) }

    it 'rejects catalog reads and mutations' do
      catalogs.each do |model, path, key, attributes|
        record = model.create!(attributes)
        [path, "#{path}/new", "#{path}/#{record.id}/edit"].each do |url|
          get url
          expect(response).to have_http_status(403)
        end
        post path, params: { key => attributes }
        expect(response).to have_http_status(403)
        patch "#{path}/#{record.id}", params: { key => { name: 'Unauthorized' } }
        expect(response).to have_http_status(403)
        delete "#{path}/#{record.id}"
        expect(response).to have_http_status(403)
        expect(record.reload.name).to eq(attributes[:name])
      end
    end

    it 'hides catalog navigation' do
      get '/admin/dashboard'
      expect(response.body).to_not include('href="/admin/agent_models"')
    end
  end

  context 'with catalog permission' do
    let(:user) { Fabricate(:user, role: Fabricate(:user_role, permissions: UserRole::FLAGS[:manage_settings])) }

    before { sign_in user }

    it 'renders Turkish labels and valid sidebar icons' do
      user.update!(locale: 'tr')
      ['/admin/agent_models', '/admin/agent_specialties', '/admin/agent_interest_profiles'].each do |path|
        get path
        expect(response).to have_http_status(200)
        expect(response.body).to_not include('translation_missing', 'SVG file not found')
        document = response.parsed_body
        expect(document.at_css('h1').text).to match(/Modeller|Uzmanlıklar|İlgi profilleri/)
        expect(document.css('nav svg.material-smart_toy, nav svg.material-category, nav svg.material-star').size).to eq(3)
      end
    end

    it 'creates, lists, edits, disables, and deletes each catalog type' do
      catalogs.each do |model, path, key, attributes|
        get "#{path}/new"
        expect(response).to have_http_status(200)
        post path, params: { key => attributes }
        expect(response).to have_http_status(302)
        record = model.order(:id).last
        get model == AgentProvider ? '/admin/agent_models' : path
        expect(response.body).to include(attributes[:name])
        get "#{path}/#{record.id}/edit"
        expect(response).to have_http_status(200)
        patch "#{path}/#{record.id}", params: { key => { name: 'Updated', enabled: false } }
        expect(response).to have_http_status(302)
        expect(record.reload).to have_attributes(name: 'Updated', enabled: false)
        delete "#{path}/#{record.id}"
        expect(response).to have_http_status(302)
        expect(model.exists?(record.id)).to be false
      end
    end

    it 'renders invalid forms without creating records' do
      catalogs.each do |model, path, key, attributes|
        expect { post path, params: { key => attributes.merge(name: '') } }.to_not change(model, :count)
        expect(response).to have_http_status(422)
      end
    end

    it 'protects providers that have models' do
      AgentModel.create!(name: 'Model', model_key: 'v1', agent_provider: provider)
      delete "/admin/agent_providers/#{provider.id}"
      expect(response).to have_http_status(302)
      expect(AgentProvider.exists?(provider.id)).to be true
    end

    it 'requires unique model IDs within each provider' do
      attributes = { name: 'Model', model_key: 'v1', agent_provider_id: provider.id }
      AgentModel.create!(attributes)
      post '/admin/agent_models', params: { agent_model: attributes }
      expect(response).to have_http_status(422)
      other = AgentProvider.create!(name: 'Other', key: 'other')
      post '/admin/agent_models', params: { agent_model: attributes.merge(agent_provider_id: other.id) }
      expect(response).to have_http_status(302)
    end

    it 'counts only enabled combinations' do
      AgentModel.create!(name: 'Model', model_key: 'v1', agent_provider: provider)
      AgentSpecialty.create!(name: 'Artist', key: 'artist')
      AgentInterestProfile.create!(name: 'Arts', key: 'arts', agent_profile_interests_attributes: [{ name: 'Art', weight: 100 }])
      get '/admin/agent_models'
      expect(response.parsed_body.at_css('.agent-catalog-summary__number').text).to eq('1')
      provider.update!(enabled: false)
      get '/admin/agent_models'
      expect(response.parsed_body.at_css('.agent-catalog-summary__number').text).to eq('0')
    end

    it 'rejects interest IDs belonging to another profile' do
      first = AgentInterestProfile.create!(name: 'First', key: 'first', agent_profile_interests_attributes: [{ name: 'Art', weight: 100 }])
      second = AgentInterestProfile.create!(name: 'Second', key: 'second', agent_profile_interests_attributes: [{ name: 'Music', weight: 100 }])
      patch "/admin/agent_interest_profiles/#{first.id}", params: { agent_interest_profile: { agent_profile_interests_attributes: [{ id: second.agent_profile_interests.first.id, name: 'Changed' }] } }
      expect(response).to have_http_status(404)
      expect(second.agent_profile_interests.first.reload.name).to eq('Music')
    end

    it 'rejects more than 100 nested interests' do
      post '/admin/agent_interest_profiles', params: { agent_interest_profile: { name: 'Large', key: 'large', agent_profile_interests_attributes: Array.new(101) { |i| { name: "Interest #{i}", weight: 1 } } } }
      expect(response).to have_http_status(422)
    end
  end
end
