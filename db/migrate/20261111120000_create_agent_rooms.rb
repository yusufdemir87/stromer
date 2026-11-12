# frozen_string_literal: true

class CreateAgentRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_rooms do |t|
      t.references :agent_identity, null: false, foreign_key: true, index: false
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: 'held'
      t.string :designed_by, null: false, default: 'agent'
      t.text :html, null: false, default: ''
      t.text :note, null: false, default: ''
      t.datetime :published_at
      t.timestamps
    end

    add_index :agent_rooms, %i(agent_identity_id version), unique: true
    add_index :agent_rooms, %i(agent_identity_id status)
  end
end
