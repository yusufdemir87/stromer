# frozen_string_literal: true

require_relative '20261029120000_populate_agent_catalog'

class SeparateOccupationsAndInterests < ActiveRecord::Migration[8.1]
  class Specialty < ActiveRecord::Base
    self.table_name = 'agent_specialties'
  end

  class Profile < ActiveRecord::Base
    self.table_name = 'agent_interest_profiles'
  end

  class Interest < ActiveRecord::Base
    self.table_name = 'agent_profile_interests'
  end

  class Identity < ActiveRecord::Base
    self.table_name = 'agent_identities'
  end

  OCCUPATIONS = <<~DATA
    doctor|Doctor
    nurse|Nurse
    dentist|Dentist
    pharmacist|Pharmacist
    physiotherapist|Physiotherapist
    psychologist|Psychologist
    veterinarian|Veterinarian
    paramedic|Paramedic
    dietitian|Dietitian
    medical_technician|Medical laboratory technician
    software_engineering|Software developer
    web_development|Web developer
    mobile_developer|Mobile app developer
    game_developer|Game developer
    data_science|Data scientist
    data_engineer|Data engineer
    databases|Database administrator
    cybersecurity|Cybersecurity analyst
    network_engineer|Network engineer
    systems_administrator|Systems administrator
    mechanical_engineering|Mechanical engineer
    electrical_engineer|Electrical engineer
    civil_engineer|Civil engineer
    chemical_engineer|Chemical engineer
    aerospace_engineer|Aerospace engineer
    industrial_engineer|Industrial engineer
    environmental_engineer|Environmental engineer
    robotics|Robotics engineer
    architecture|Architect
    surveyor|Surveyor
    machinist|Machinist
    mechanic|Mechanic
    electrician|Electrician
    plumber|Plumber
    carpenter|Carpenter
    welder|Welder
    mason|Mason
    roofer|Roofer
    locksmith|Locksmith
    hvac_technician|HVAC technician
    driver|Driver
    truck_driver|Truck driver
    bus_driver|Bus driver
    train_driver|Train driver
    pilot|Pilot
    ship_captain|Ship captain
    courier|Courier
    logistics_coordinator|Logistics coordinator
    air_traffic_controller|Air traffic controller
    warehouse_manager|Warehouse manager
    painting|Painter
    illustration|Illustrator
    graphic_design|Graphic designer
    photography|Photographer
    animation|Animator
    sculpture|Sculptor
    fashion_design|Fashion designer
    interior_design|Interior designer
    musician|Musician
    actor|Actor
    fiction_writing|Novelist
    poetry|Poet
    screenwriting|Screenwriter
    journalist|Journalist
    editor|Editor
    translation|Translator
    teacher|Teacher
    librarian|Librarian
    historian|Historian
    mathematics|Mathematician
    finance_expert|Finance expert
    accountant|Accountant
    auditor|Auditor
    economist|Economist
    financial_analyst|Financial analyst
    insurance_specialist|Insurance specialist
    business_analyst|Business analyst
    entrepreneur|Entrepreneur
    marketing_manager|Marketing manager
    human_resources|Human resources specialist
    lawyer|Lawyer
    judge|Judge
    diplomat|Diplomat
    social_worker|Social worker
    firefighter|Firefighter
    police_officer|Police officer
    urban_planning|Urban planner
    researcher|Research scientist
    biologist|Biologist
    chemist|Chemist
    chef|Chef
    baker|Baker
    farmer|Farmer
    gardener|Gardener
    tailor|Tailor
    barber|Barber
    hotel_manager|Hotel manager
    tour_guide|Tour guide
    fitness_trainer|Fitness trainer
    sports_coach|Sports coach
  DATA

  INTERESTS = <<~DATA
    swimming|Swimming
    hiking|Hiking
    sports|Sports
    books|Books
    technology|Technology
    travel|Travel
    music|Music
    movies|Movies
    cooking|Cooking
    gardening|Gardening
    football|Football
    basketball|Basketball
    tennis|Tennis
    volleyball|Volleyball
    running|Running
    cycling|Cycling
    climbing|Climbing
    skiing|Skiing
    surfing|Surfing
    sailing|Sailing
    yoga|Yoga
    pilates|Pilates
    martial_arts|Martial arts
    boxing|Boxing
    golf|Golf
    badminton|Badminton
    table_tennis|Table tennis
    skating|Skating
    horse_riding|Horse riding
    archery|Archery
    camping|Camping
    backpacking|Backpacking
    birdwatching|Birdwatching
    stargazing|Stargazing
    fishing|Fishing
    nature|Nature
    wildlife|Wildlife
    plants|Plants
    oceans|Oceans
    weather|Weather
    photography|Photography
    painting|Painting
    drawing|Drawing
    pottery|Pottery
    knitting|Knitting
    sewing|Sewing
    woodworking|Woodworking
    origami|Origami
    calligraphy|Calligraphy
    jewellery_making|Jewellery making
    fiction_writing|Fiction writing
    poetry|Poetry
    science_fiction|Science fiction
    fantasy|Fantasy
    mystery_books|Mystery books
    biographies|Biographies
    history|History
    philosophy|Philosophy
    languages|Languages
    mythology|Mythology
    jazz|Jazz
    classical_music|Classical music
    rock_music|Rock music
    folk_music|Folk music
    electronic_music|Electronic music
    singing|Singing
    guitar|Guitar
    piano|Piano
    dance|Dance
    theatre|Theatre
    chess|Chess
    board_games|Board games
    video_games|Video games
    puzzles|Puzzles
    mathematics|Mathematics
    astronomy|Astronomy
    robotics|Robotics
    coding|Coding
    electronics|Electronics
    space_exploration|Space exploration
    baking|Baking
    coffee|Coffee
    tea|Tea
    world_cuisines|World cuisines
    food_history|Food history
    fashion|Fashion
    home_design|Home design
    architecture|Architecture
    museums|Museums
    local_culture|Local culture
    volunteering|Volunteering
    sustainability|Sustainability
    recycling|Recycling
    animal_welfare|Animal welfare
    pets|Pets
    cars|Cars
    motorcycles|Motorcycles
    trains|Trains
    aviation|Aviation
    collecting|Collecting
  DATA

  def up
    occupations = rows(OCCUPATIONS)
    interests = rows(INTERESTS)
    original = PopulateAgentCatalog::CATALOG.lines.map { |line| line.strip.split('|') }

    # Correct only untouched records from our earlier seed. Keep operator-authored
    # records, and retain referenced obsolete rows (disabled) to preserve identities.
    original.each do |key, name, *mix|
      specialty = Specialty.find_by(key: key)
      if specialty && original_specialty?(specialty, name, mix)
        if occupations.key?(key)
          specialty.update!(specialty_attributes(occupations.fetch(key)))
        else
          retire_or_delete(specialty, :agent_specialty_id)
        end
      end

      profile = Profile.find_by(key: key)
      next unless profile && original_profile?(profile, mix)

      if interests.key?(key)
        profile.update!(profile_attributes(interests.fetch(key)))
        replace_mix(profile, interests.fetch(key))
      else
        retire_or_delete(profile, :agent_interest_profile_id)
      end
    end

    occupations.each do |key, name|
      Specialty.find_or_create_by!(key: key) { |record| record.assign_attributes(specialty_attributes(name)) }
    end
    interests.each do |key, name|
      next if Profile.exists?(key: key)

      profile = Profile.create!(key: key, **profile_attributes(name))
      replace_mix(profile, name)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'The corrected catalog may be edited or referenced by agents.'
  end

  private

  def rows(data)
    data.lines.to_h { |line| line.strip.split('|', 2) }
  end

  def specialty_attributes(name)
    {
      name: name,
      description: "Occupation: #{name}. Independent of the agent's hobbies and interests.",
      capabilities: "Knowledge and workflows associated with the #{name.downcase} role. This is an AI persona, not a human professional or proof of qualifications. Tools and real-world actions require separately granted capabilities.",
    }
  end

  def profile_attributes(name)
    { name: name, description: "Personal interest: #{name}. Can be combined with any occupation and model." }
  end

  def replace_mix(profile, name)
    Interest.where(agent_interest_profile_id: profile.id).delete_all
    Interest.create!(agent_interest_profile_id: profile.id, name: name, weight: 100)
  end

  def original_specialty?(record, name, mix)
    record.name == name &&
      record.description == "AI specialty focused on #{mix.first.downcase}, with context from #{mix.drop(1).join(' and ').downcase}." &&
      record.capabilities == "Explain #{mix.first.downcase}, compare sources and draft educational commentary. Identify uncertainty and cite factual claims. This catalog entry grants no tools, professional credentials or authority to provide personal advice."
  end

  def original_profile?(record, mix)
    record.name == "#{mix.first} explorer" &&
      record.description == "An interest mix of #{mix.join(', ')} (60%, 25%, 15%)." &&
      Interest.where(agent_interest_profile_id: record.id).pluck(:name, :weight).sort == mix.zip([60, 25, 15]).sort
  end

  def retire_or_delete(record, foreign_key)
    if Identity.exists?(foreign_key => record.id)
      record.update!(enabled: false)
    else
      Interest.where(agent_interest_profile_id: record.id).delete_all if record.is_a?(Profile)
      record.delete
    end
  end
end
