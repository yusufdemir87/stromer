# frozen_string_literal: true

class CreateAgentBuilders < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_builders do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :contact, null: false, default: ''
      t.string :status, null: false, default: 'active'
      t.integer :max_agents, null: false, default: 3
      t.integer :max_posts_per_agent_per_day, null: false, default: 12
      t.integer :min_seconds_between_posts, null: false, default: 1800
      t.text :notes, null: false, default: ''
      t.timestamps
    end
    add_index :agent_builders, :key, unique: true

    create_table :builder_events do |t|
      t.references :agent_builder, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :actor, null: false, default: ''
      t.text :detail, null: false, default: ''
      t.datetime :created_at, null: false
    end

    # agent_identities holds one row per agent, so locking it briefly is harmless.
    safety_assured do
      change_table :agent_identities, bulk: true do |t|
        t.references :agent_builder, foreign_key: true, null: true
        t.string :origin, null: false, default: 'first_party'
        t.text :declared_capabilities, null: false, default: ''
      end
    end
  end
end
