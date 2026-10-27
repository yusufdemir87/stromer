# frozen_string_literal: true

# Loads providers, models, specialties and interest profiles from a JSON document into the agent catalog, so a
# few hundred entries need not be typed into the admin panel. Rerunning with the same file changes nothing; a
# changed file updates what changed. Nothing is deleted: entries that are no longer in the file stay as they are.
#
# The document: { "providers": [{ "key", "name", "description", "models": [{ "model_key", "name", "description" }] }],
# "specialties": [{ "key", "name", "description", "capabilities" }],
# "interest_profiles": [{ "key", "name", "description", "interests": [{ "name", "weight" }] }] }. Every section is optional.
#
# All or nothing: if any entry is invalid, nothing is saved and the problems are returned.
class AgentCatalogImporter
  KINDS = %w(providers models specialties interest_profiles).freeze

  Result = Struct.new(:counts, :errors, :dry_run) do
    def ok?
      errors.empty?
    end
  end

  def initialize(document, dry_run: false)
    @document = document
    @dry_run = dry_run
    @counts = KINDS.index_with { { created: 0, updated: 0, unchanged: 0 } }
    @errors = []
  end

  def call
    ActiveRecord::Base.transaction do
      import_providers
      import_specialties
      import_interest_profiles
      raise ActiveRecord::Rollback if @errors.any? || @dry_run
    end

    Result.new(@counts, @errors, @dry_run)
  end

  private

  def section(name)
    value = @document[name]
    return [] if value.nil?

    unless value.is_a?(Array)
      @errors << "#{name} must be a list"
      return []
    end

    value.select do |item|
      next true if item.is_a?(Hash)

      @errors << "#{name}: each entry must be an object"
      false
    end
  end

  def import_providers
    section('providers').each do |entry|
      provider = AgentProvider.find_or_initialize_by(key: entry['key'].to_s.strip.downcase)
      save(provider, 'providers', entry, attributes(entry, 'name', 'description'))
      next if provider.errors.any? || !provider.persisted?

      Array(entry['models']).grep(Hash).each do |model_entry|
        model = AgentModel.find_or_initialize_by(agent_provider: provider, model_key: model_entry['model_key'].to_s.strip)
        save(model, 'models', model_entry, attributes(model_entry, 'name', 'description'), label: "#{provider.key}/#{model_entry['model_key']}")
      end
    end
  end

  def import_specialties
    section('specialties').each do |entry|
      record = AgentSpecialty.find_or_initialize_by(key: entry['key'].to_s.strip.downcase)
      save(record, 'specialties', entry, attributes(entry, 'name', 'description', 'capabilities'))
    end
  end

  def import_interest_profiles
    section('interest_profiles').each do |entry|
      record = AgentInterestProfile.find_or_initialize_by(key: entry['key'].to_s.strip.downcase)
      attrs = attributes(entry, 'name', 'description')
      attrs[:agent_profile_interests_attributes] = interest_attributes(record, entry['interests'])
      save(record, 'interest_profiles', entry, attrs)
    end
  end

  # Replaces the interests only when they differ, so a rerun leaves the rows (and their ids) alone.
  def interest_attributes(record, interests)
    wanted = Array(interests).filter_map { |item| { name: item['name'].to_s.strip, weight: item['weight'].to_i } if item.is_a?(Hash) }
    current = record.agent_profile_interests.map { |item| { name: item.name, weight: item.weight } }
    return [] if record.persisted? && current.sort_by { |item| item[:name] } == wanted.sort_by { |item| item[:name] }

    record.agent_profile_interests.map { |item| { id: item.id, _destroy: true } } + wanted
  end

  def attributes(entry, *names)
    names.each_with_object({}) { |name, result| result[name.to_sym] = entry[name].to_s if entry.key?(name) }
  end

  def save(record, kind, entry, attrs, label: nil)
    label ||= entry['key'].to_s
    record.assign_attributes(attrs)
    status = if record.new_record? then :created
             elsif record.changed_for_autosave? then :updated
             else :unchanged
             end

    if status == :unchanged || record.save
      @counts[kind][status] += 1
    else
      @errors << "#{kind} #{label}: #{record.errors.full_messages.to_sentence}"
    end
  end
end
