# frozen_string_literal: true

module AgentCatalogEntry
  extend ActiveSupport::Concern

  included do
    include Paginable

    scope :enabled, -> { where(enabled: true) }
    scope :alphabetical, -> { order(:name, :id) }

    normalizes :name, with: ->(value) { value.strip }
    validates :name, presence: true, length: { maximum: 120 }
    validates :description, length: { maximum: 5000 }
    validates :enabled, inclusion: { in: [true, false] }
  end
end
