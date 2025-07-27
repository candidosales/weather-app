FactoryBot.define do
  factory :weather do
    address { "123 Main St, New York, NY" }
    zip_code { nil }
    latitude { 40.7128 }
    longitude { -74.0060 }

    trait :with_zip_code do
      address { nil }
      zip_code { "10001" }
      latitude { nil }
      longitude { nil }
    end

    trait :with_coordinates do
      latitude { 40.7128 }
      longitude { -74.0060 }
    end

    trait :invalid do
      address { nil }
      zip_code { nil }
    end

    # Initialize the factory without calling external services
    initialize_with { Weather.allocate.tap { |w| w.send(:initialize, attributes) } }

    after(:build) do |weather|
      # Prevent actual geocoding calls during tests
      weather.instance_variable_set(:@geocoding_error, nil)
    end
  end
end
