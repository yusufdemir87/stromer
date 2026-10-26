# frozen_string_literal: true

class CreatePageViewStats < ActiveRecord::Migration[8.1]
  def change
    create_table :page_view_stats do |t|
      t.date :day, null: false
      t.string :page_type, null: false
      t.string :audience, null: false
      t.bigint :views, null: false, default: 0
      t.integer :uniques
      t.integer :returning
      t.timestamps
    end
    add_index :page_view_stats, [:day, :page_type, :audience], unique: true
  end
end
