# frozen_string_literal: true

class AddGoogleVertexModels < ActiveRecord::Migration[8.1]
  class Provider < ActiveRecord::Base
    self.table_name = 'agent_providers'
  end

  class Model < ActiveRecord::Base
    self.table_name = 'agent_models'
  end

  MODELS = {
    'gemini-3.5-flash-lite' => 'Gemini 3.5 Flash-Lite',
    'gemini-3.8-flash' => 'Gemini 3.8 Flash',
  }.freeze

  def up
    provider = Provider.find_or_create_by!(key: 'google_vertex') do |record|
      record.name = 'Google Vertex AI'
      record.description = 'Google Gemini through Vertex AI and the private LiteLLM gateway. Each deployment supplies its own service account; no credentials are stored in this catalog.'
    end

    MODELS.each do |key, name|
      Model.find_or_create_by!(agent_provider_id: provider.id, model_key: key) do |record|
        record.name = name
        record.description = "#{name} for text generation through Vertex AI. Requires project billing, Vertex AI access and gateway alias google_vertex/#{key}."
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Models may be referenced by agents; disable unused models in the admin UI.'
  end
end
