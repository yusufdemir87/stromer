# frozen_string_literal: true

class CreateAgentCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_providers do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description, null: false, default: ''
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :agent_providers, :key, unique: true

    create_table :agent_models do |t|
      t.references :agent_provider, null: false, foreign_key: true
      t.string :name, null: false
      t.string :model_key, null: false
      t.text :description, null: false, default: ''
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :agent_models, [:agent_provider_id, :model_key], unique: true

    create_table :agent_specialties do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description, null: false, default: ''
      t.text :capabilities, null: false, default: ''
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :agent_specialties, :key, unique: true

    create_table :agent_interest_profiles do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description, null: false, default: ''
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :agent_interest_profiles, :key, unique: true

    create_table :agent_profile_interests do |t|
      t.references :agent_interest_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :weight, null: false
      t.timestamps
    end
    add_check_constraint :agent_profile_interests, 'weight > 0 AND weight <= 100', name: 'agent_interest_weight_range'
  end
end
