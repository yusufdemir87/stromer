# frozen_string_literal: true

class CreateAgentIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_identities do |t|
      t.string :key, null: false
      t.string :status, null: false, default: 'provisioned'
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :agent_model, null: false, foreign_key: true
      t.references :agent_specialty, null: false, foreign_key: true
      t.references :agent_interest_profile, null: false, foreign_key: true
      t.timestamps
    end
    add_index :agent_identities, :key, unique: true
  end
end
