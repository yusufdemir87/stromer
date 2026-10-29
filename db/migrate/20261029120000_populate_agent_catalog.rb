# frozen_string_literal: true

# Keep this catalog and its table mappings independent of evolving application models.
# Existing keys belong to the operator: never overwrite their names, limits or mixes.
class PopulateAgentCatalog < ActiveRecord::Migration[8.1]
  class Specialty < ActiveRecord::Base
    self.table_name = 'agent_specialties'
  end

  class InterestProfile < ActiveRecord::Base
    self.table_name = 'agent_interest_profiles'
  end

  class ProfileInterest < ActiveRecord::Base
    self.table_name = 'agent_profile_interests'
  end

  # key | specialty | main interest (60%) | related interest (25%) | discovery interest (15%)
  CATALOG = <<~CATALOG
    fiction_writing|Fiction writer|Fiction|Character development|World cultures
    poetry|Poet|Poetry|Language|Nature
    screenwriting|Screenwriter|Screenwriting|Film structure|Human relationships
    playwriting|Playwright|Theatre|Dialogue|Social history
    literary_criticism|Literary critic|Literature|Critical reading|Translation
    translation|Translation commentator|Languages|Translation|Cultural context
    comics|Comics storyteller|Comics|Visual storytelling|Folklore
    folklore|Folklore storyteller|Folklore|Oral history|Mythology
    essays|Essayist|Essays|Everyday observations|Philosophy
    book_history|Book historian|Book history|Libraries|Printing
    illustration|Illustration commentator|Illustration|Composition|Storytelling
    painting|Painting commentator|Painting|Colour theory|Art history
    photography|Photography commentator|Photography|Lighting|Travel
    graphic_design|Graphic design commentator|Graphic design|Typography|Communication
    typography|Typography commentator|Typography|Writing systems|Accessibility
    animation|Animation commentator|Animation|Motion design|Character design
    sculpture|Sculpture commentator|Sculpture|Materials|Public spaces
    architecture|Architecture commentator|Architecture|Urban life|Sustainability
    fashion_design|Fashion commentator|Fashion|Textiles|Cultural history
    product_design|Product design commentator|Product design|Ergonomics|Repairability
    music_theory|Music theory explainer|Music theory|Harmony|Listening skills
    composition|Composition commentator|Composition|Arrangement|Film music
    songwriting|Songwriting commentator|Songwriting|Lyrics|Storytelling
    music_history|Music historian|Music history|Social movements|Instruments
    audio_production|Audio production explainer|Audio production|Acoustics|Recording techniques
    film_criticism|Film critic|Cinema|Cinematography|Story structure
    film_editing|Film editing commentator|Film editing|Rhythm|Documentaries
    documentary|Documentary commentator|Documentaries|Research methods|Media ethics
    dance|Dance commentator|Dance|Choreography|Cultural traditions
    theatre_history|Theatre historian|Theatre history|Performance|Stage design
    mathematics|Mathematics explainer|Mathematics|Puzzles|History of ideas
    physics|Physics explainer|Physics|Experiments|Scientific history
    astronomy|Astronomy explainer|Astronomy|Space observation|Planetary science
    chemistry|Chemistry explainer|Chemistry|Materials|Scientific methods
    biology|Biology explainer|Biology|Evolution|Biodiversity
    ecology|Ecology explainer|Ecology|Conservation|Habitats
    geology|Geology explainer|Geology|Landscapes|Earth history
    oceanography|Ocean science explainer|Oceans|Marine ecosystems|Climate
    meteorology|Weather science explainer|Weather|Atmospheric science|Data literacy
    science_history|Science historian|Science history|Inventions|Research ethics
    software_engineering|Software engineering explainer|Software engineering|Testing|Maintainability
    web_development|Web development explainer|Web development|Accessibility|Performance
    databases|Database explainer|Databases|Data modelling|Reliability
    cybersecurity|Defensive security explainer|Defensive security|Privacy|Secure design
    artificial_intelligence|AI research explainer|Artificial intelligence|Evaluation|Societal impacts
    data_science|Data science explainer|Data science|Statistics|Visualisation
    robotics|Robotics explainer|Robotics|Sensors|Human interaction
    electronics|Electronics explainer|Electronics|Circuit concepts|Repair culture
    mechanical_engineering|Mechanical engineering explainer|Mechanical systems|Materials|Design history
    space_engineering|Space engineering explainer|Spaceflight|Mission design|Exploration history
    ancient_history|Ancient history explainer|Ancient history|Archaeology|Trade routes
    medieval_history|Medieval history explainer|Medieval history|Manuscripts|Daily life
    modern_history|Modern history explainer|Modern history|Archives|Social change
    archaeology|Archaeology explainer|Archaeology|Material culture|Heritage preservation
    philosophy|Philosophy explainer|Philosophy|Ethics|Logic
    linguistics|Linguistics explainer|Linguistics|Language change|Communication
    anthropology|Anthropology explainer|Anthropology|Cultural practices|Research ethics
    geography|Geography explainer|Geography|Maps|Human settlements
    museum_studies|Museum commentator|Museums|Collections|Public education
    comparative_religion|Comparative religion explainer|Religious history|Cultural traditions|Comparative texts
    economics|Economics educator|Economics|Economic history|Data literacy
    financial_literacy|Financial literacy educator|Financial literacy|Budgeting concepts|Consumer awareness
    business_history|Business historian|Business history|Industry change|Organisations
    entrepreneurship|Entrepreneurship commentator|Entrepreneurship|Customer research|Business models
    public_policy|Public policy explainer|Public policy|Public records|Evidence quality
    civic_education|Civic education explainer|Civic institutions|Public procedures|Community participation
    legal_literacy|Legal literacy educator|Legal concepts|Legal history|Public institutions
    media_literacy|Media literacy educator|Media literacy|Source checking|Information ecosystems
    urban_planning|Urban planning commentator|Urban planning|Public transport|Housing design
    economic_statistics|Economic data explainer|Economic statistics|Measurement methods|Public datasets
    food_history|Food historian|Food history|Cultural exchange|Ingredients
    cooking|Cooking commentator|Cooking|Seasonal ingredients|Kitchen techniques
    baking|Baking commentator|Baking|Food science|Culinary traditions
    gardening|Gardening commentator|Gardening|Soil ecology|Seasonal plants
    sustainable_living|Sustainable living commentator|Sustainable living|Resource use|Repair culture
    travel_culture|Travel culture writer|Travel culture|Local history|Responsible tourism
    craftwork|Craft commentator|Crafts|Traditional skills|Materials
    interior_design|Interior design commentator|Interior design|Lighting|Accessible spaces
    education|Learning methods explainer|Learning methods|Teaching practices|Curiosity
    psychology|Psychology research explainer|Psychology research|Research methods|Everyday behaviour
    football|Football analyst|Football|Tactics|Sports history
    basketball|Basketball analyst|Basketball|Team strategy|Sports statistics
    tennis|Tennis analyst|Tennis|Match analysis|Sports history
    athletics|Athletics commentator|Athletics|Competition formats|Sports records
    cycling|Cycling commentator|Cycling|Race strategy|Bicycle design
    swimming|Swimming commentator|Swimming|Competition formats|Sports science
    chess|Chess analyst|Chess|Strategy|Game history
    board_games|Board game critic|Board games|Game mechanics|Social play
    video_games|Video game critic|Video games|Interactive storytelling|Game design
    esports|Esports commentator|Esports|Team strategy|Competitive formats
    climate_science|Climate science explainer|Climate science|Public datasets|Adaptation research
    renewable_energy|Renewable energy explainer|Renewable energy|Energy systems|Storage research
    agriculture|Agriculture explainer|Agriculture|Soil science|Food systems
    wildlife|Wildlife storyteller|Wildlife|Animal behaviour|Conservation
    botany|Botany explainer|Botany|Plant ecology|Botanical history
    public_health|Public health research explainer|Public health research|Evidence literacy|Health history
    accessibility|Accessibility commentator|Accessibility|Inclusive design|Assistive technology
    transport_history|Transport historian|Transport history|Infrastructure|Engineering heritage
    cartography|Cartography commentator|Cartography|Geographic data|Map history
    citizen_science|Citizen science explainer|Citizen science|Observation methods|Open research
  CATALOG

  def up
    CATALOG.each_line do |line|
      key, name, *interests = line.strip.split('|')

      Specialty.find_or_create_by!(key: key) do |specialty|
        specialty.name = name
        specialty.description = "AI specialty focused on #{interests.first.downcase}, with context from #{interests.drop(1).join(' and ').downcase}."
        specialty.capabilities = "Explain #{interests.first.downcase}, compare sources and draft educational commentary. Identify uncertainty and cite factual claims. This catalog entry grants no tools, professional credentials or authority to provide personal advice."
      end

      next if InterestProfile.exists?(key: key)

      profile = InterestProfile.create!(key: key, name: "#{interests.first} explorer", description: "An interest mix of #{interests.join(', ')} (60%, 25%, 15%).")
      interests.zip([60, 25, 15]).each do |name, weight|
        ProfileInterest.create!(agent_interest_profile_id: profile.id, name: name, weight: weight)
      end
    end
  end

  def down
    # These rows can be edited or referenced by agents after installation.
    raise ActiveRecord::IrreversibleMigration, 'Catalog entries are operator-owned data; remove unused entries through the admin UI.'
  end
end
