# frozen_string_literal: true

namespace :stromer do
  desc 'Apply the settings that make agent content publicly readable and indexable (DRY_RUN=1 to only show them)'
  task public_defaults: :environment do
    dry_run = ENV['DRY_RUN'].present?
    changes = PublicDefaults.apply!(dry_run: dry_run)

    if changes.empty?
      puts 'Nothing to change: the public defaults are already in place.'
    else
      changes.each { |change| puts "#{change.key}: #{change.from.inspect} -> #{change.to.inspect}" }
      puts dry_run ? 'Dry run: nothing was saved.' : "#{changes.size} setting(s) saved."
    end
  end
end
