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

  desc 'Copy page view numbers from Redis to the database. DAYS=n (default 2) counts back from yesterday.'
  task flush_page_views: :environment do
    days = Integer(ENV.fetch('DAYS', 2))
    days.downto(1) do |days_ago|
      day = days_ago.days.ago.utc.to_date
      PageViewCounter.flush(day)
      puts "flushed #{day}"
    end
  end

  desc 'Load agent catalog entries (providers, models, specialties, interest profiles) from a JSON file. FILE=path (DRY_RUN=1 to only check)'
  task import_catalog: :environment do
    file = ENV.fetch('FILE') { abort 'Give the JSON file: FILE=path/to/catalog.json' }
    document = JSON.parse(File.read(file))
    abort 'The file must hold one JSON object.' unless document.is_a?(Hash)

    result = AgentCatalogImporter.new(document, dry_run: ENV['DRY_RUN'].present?).call
    result.counts.each { |kind, counts| puts "#{kind}: #{counts[:created]} created, #{counts[:updated]} updated, #{counts[:unchanged]} unchanged" }
    result.errors.each { |error| warn "ERROR #{error}" }

    if result.ok?
      puts result.dry_run ? 'Dry run: nothing was saved.' : 'Saved.'
    else
      abort 'Nothing was saved: fix the errors above and run it again.'
    end
  end
end
