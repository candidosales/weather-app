require 'rails_helper'

RSpec.shared_context("with cache", :with_cache) do
  # Inclusion of this context enables and mocks cache.
  # Allows Rails.cache to behave just like it would on dev and prod!
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    # Create a new memory store for each test
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end
end

RSpec.describe WeatherService do
  include ActiveSupport::Testing::TimeHelpers

  subject(:weather_service) { described_class.new }

  let(:valid_lat) { 37.7749 }
  let(:valid_lon) { -122.4194 }
  let(:valid_zip) { "94105" }
  let(:api_key) { "test_api_key_123" }

  # Load fixture responses
  let(:mock_weather_response) do
    JSON.parse(file_fixture("weather_response.json").read)
  end

  let(:mock_forecast_response) do
    JSON.parse(file_fixture("forecast_response.json").read)
  end

  let(:mock_geocoder_result) do
    double("Geocoder::Result",
      latitude: valid_lat,
      longitude: valid_lon,
      city: "San Francisco",
      state: "CA",
      country: "US"
    )
  end

  before do
    # Mock API key
    allow(Rails.application.credentials).to receive(:openweather_api_key).and_return(api_key)

    # Reset the memoized API key before each test
    described_class.instance_variable_set(:@api_key, nil)
  end

  describe '.api_key' do
    context 'when API key is in credentials' do
      it 'returns the API key from credentials' do
        expect(described_class.api_key).to eq(api_key)
      end
    end

    context 'when API key is in environment variable' do
      before do
        allow(Rails.application.credentials).to receive(:openweather_api_key).and_return(nil)
        ENV['OPENWEATHER_API_KEY'] = 'env_api_key'
      end

      after do
        ENV.delete('OPENWEATHER_API_KEY')
      end

      it 'returns the API key from environment' do
        # Reset the memoized value
        described_class.instance_variable_set(:@api_key, nil)
        expect(described_class.api_key).to eq('env_api_key')
      end
    end

    context 'when no API key is configured' do
      before do
        allow(Rails.application.credentials).to receive(:openweather_api_key).and_return(nil)
        ENV.delete('OPENWEATHER_API_KEY')
      end

      it 'raises ApiKeyError' do
        # Reset the memoized value
        described_class.instance_variable_set(:@api_key, nil)
        expect { described_class.api_key }.to raise_error(WeatherService::ApiKeyError, "OpenWeather API key not configured")
      end
    end
  end

  describe '#get_current_weather' do
    context 'with valid coordinates' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s, appid: api_key, units: "metric"))
          .to_return(status: 200, body: mock_weather_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns weather data' do
        result = weather_service.get_current_weather(valid_lat, valid_lon)

        expect(result).to include("main", "weather", "coord")
        expect(result["main"]["temp"]).to eq(22.5)
        expect(result["weather"].first["main"]).to eq("Clear")
      end

      it 'caches the result', :with_cache do
        # First call
        weather_service.get_current_weather(valid_lat, valid_lon)

        # Second call should hit cache
        expect(Rails.cache).to receive(:fetch).with("weather_current_#{valid_lat}_#{valid_lon}", expires_in: WeatherConfig.cache_expiry).and_call_original
        weather_service.get_current_weather(valid_lat, valid_lon)
      end
    end

    context 'with invalid coordinates' do
      it 'raises InvalidLocationError for invalid latitude' do
        expect { weather_service.get_current_weather(91, valid_lon) }.to raise_error(
          WeatherService::InvalidLocationError,
          "Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180"
        )
      end

      it 'raises InvalidLocationError for invalid longitude' do
        expect { weather_service.get_current_weather(valid_lat, 181) }.to raise_error(
          WeatherService::InvalidLocationError,
          "Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180"
        )
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
          .to_return(status: 401, body: { cod: 401, message: "Invalid API key" }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError' do
        expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(
          WeatherService::ApiError, "Invalid API key"
        )
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
          .to_raise(SocketError.new("Network error"))
      end

      it 'raises the network error' do
        expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(SocketError)
      end
    end
  end

  describe '#get_forecast' do
    context 'with valid coordinates' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s, appid: api_key, units: "metric"))
          .to_return(status: 200, body: mock_forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns forecast data' do
        result = weather_service.get_forecast(valid_lat, valid_lon)

        expect(result).to have_key("list")
        expect(result["list"]).to be_an(Array)
        expect(result["list"].first).to include("main", "weather", "dt_txt")
      end

      it 'caches the result', :with_cache do
        # First call
        weather_service.get_forecast(valid_lat, valid_lon)

        # Second call should hit cache
        expect(Rails.cache).to receive(:fetch).with("weather_forecast_#{valid_lat}_#{valid_lon}", expires_in: WeatherConfig.cache_expiry).and_call_original
        weather_service.get_forecast(valid_lat, valid_lon)
      end
    end

    context 'with invalid coordinates' do
      it 'raises InvalidLocationError for invalid coordinates' do
        expect { weather_service.get_forecast(-91, valid_lon) }.to raise_error(
          WeatherService::InvalidLocationError,
          "Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180"
        )
      end
    end
  end

  describe '#get_weather_by_zip' do
    context 'with valid zip code' do
      before do
        allow(Geocoder).to receive(:search).with(valid_zip).and_return([ mock_geocoder_result ])

        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
          .to_return(status: 200, body: mock_weather_response.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
          .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
          .to_return(status: 200, body: mock_forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns combined weather data with coordinates' do
        result = weather_service.get_weather_by_zip(valid_zip)

        expect(result).to include(:current, :forecast, :coordinates, :from_cache)
        expect(result[:coordinates]).to include(:lat, :lon, :city, :state, :country)
        expect(result[:current]).to include("main", "weather")
        expect(result[:forecast]).to include("list")
        expect(result[:from_cache]).to be false
      end

      it 'caches the result', :with_cache do
        # First call
        weather_service.get_weather_by_zip(valid_zip)

        # Second call should hit cache
        expect(Rails.cache).to receive(:fetch).with("weather_current_#{valid_lat}_#{valid_lon}", expires_in: WeatherConfig.cache_expiry).and_call_original
        expect(Rails.cache).to receive(:fetch).with("weather_forecast_#{valid_lat}_#{valid_lon}", expires_in: WeatherConfig.cache_expiry).and_call_original

        weather_service.get_weather_by_zip(valid_zip)
      end
    end

    context 'with invalid zip code' do
      it 'returns error for blank zip code' do
        result = weather_service.get_weather_by_zip("")
        expect(result).to have_key(:error)
        expect(result[:error]).to eq("Zip code cannot be blank")
      end

      it 'returns error for nil zip code' do
        result = weather_service.get_weather_by_zip(nil)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq("Zip code cannot be blank")
      end
    end

    context 'when geocoding fails' do
      before do
        allow(Geocoder).to receive(:search).with("invalid_zip").and_return([])
      end

      it 'returns error for location not found' do
        result = weather_service.get_weather_by_zip("invalid_zip")
        expect(result).to have_key(:error)
        expect(result[:error]).to include("Location not found for zip code")
      end
    end

    context 'when geocoding service error occurs' do
      before do
        allow(Geocoder).to receive(:search).with(valid_zip).and_raise(Geocoder::Error.new("Service unavailable"))
      end

      it 'returns error for geocoding service error' do
        result = weather_service.get_weather_by_zip(valid_zip)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq("Weather service temporarily unavailable")
      end
    end

    context 'when API errors occur' do
      before do
        allow(Geocoder).to receive(:search).with(valid_zip).and_return([ mock_geocoder_result ])
      end

      context 'when current weather API fails' do
        before do
          stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
            .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
            .to_return(status: 401, body: { cod: 401, message: "Invalid API key" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns generic error message' do
          result = weather_service.get_weather_by_zip(valid_zip)
          expect(result).to have_key(:error)
          expect(result[:error]).to eq("Weather service temporarily unavailable")
        end
      end

      context 'when forecast API fails' do
        before do
          stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
            .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
            .to_return(status: 200, body: mock_weather_response.to_json, headers: { 'Content-Type' => 'application/json' })

          stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
            .with(query: hash_including(lat: valid_lat.to_s, lon: valid_lon.to_s))
            .to_return(status: 500, body: { cod: 500, message: "Server error" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns generic error message' do
          result = weather_service.get_weather_by_zip(valid_zip)
          expect(result).to have_key(:error)
          expect(result[:error]).to eq("Weather service temporarily unavailable")
        end
      end
    end
  end

  describe 'error handling' do
    describe 'API response codes' do
      let(:base_url) { "https://api.openweathermap.org/data/2.5/weather" }

      context 'when API returns 401 (unauthorized)' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_return(status: 401, body: { cod: 401, message: "Invalid API key" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'raises ApiError' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(
            WeatherService::ApiError, "Invalid API key"
          )
        end
      end

      context 'when API returns 404 (not found)' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_return(status: 404, body: { cod: 404, message: "city not found" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'raises ApiError' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(
            WeatherService::ApiError, "Location not found"
          )
        end
      end

      context 'when API returns 429 (rate limit)' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_return(status: 429, body: { cod: 429, message: "Rate limit exceeded" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'raises ApiError' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(
            WeatherService::ApiError, "API rate limit exceeded. Please try again later"
          )
        end
      end

      context 'when API returns 500 (server error)' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_return(status: 500, body: { cod: 500, message: "Internal server error" }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'raises StandardError' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(
            WeatherService::ApiError, "API Error: 500 - Service unavailable"
          )
        end
      end
    end

    describe 'network errors' do
      let(:base_url) { "https://api.openweathermap.org/data/2.5/weather" }

      context 'when timeout occurs' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_raise(Timeout::Error.new("Timeout"))
        end

        it 'raises the timeout error' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(Timeout::Error)
        end
      end

      context 'when connection refused' do
        before do
          stub_request(:get, base_url)
            .with(query: hash_including(appid: api_key))
            .to_raise(Errno::ECONNREFUSED.new("Connection refused"))
        end

        it 'raises the connection error' do
          expect { weather_service.get_current_weather(valid_lat, valid_lon) }.to raise_error(Errno::ECONNREFUSED)
        end
      end
    end
  end

  describe 'logging' do
    let(:logger) { double('Logger') }

    before do
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:error)
    end

    context 'when error occurs in get_weather_by_zip' do
      before do
        allow(Geocoder).to receive(:search).with(valid_zip).and_raise(Geocoder::Error.new("Service unavailable"))
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with(/WeatherService: Unexpected error getting weather by zip code/)
        weather_service.get_weather_by_zip(valid_zip)
      end
    end

    context 'when InvalidLocationError occurs in get_weather_by_zip' do
      before do
        allow(Geocoder).to receive(:search).with("invalid_zip").and_return([])
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with(/WeatherService: Failed to get weather by zip code invalid_zip/)
        weather_service.get_weather_by_zip("invalid_zip")
      end
    end
  end

  describe 'caching behavior', :with_cache do
    before do
      stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
        .to_return(status: 200, body: mock_weather_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'uses correct cache keys' do
      expect(Rails.cache).to receive(:fetch).with("weather_current_#{valid_lat}_#{valid_lon}", expires_in: WeatherConfig.cache_expiry)
      weather_service.get_current_weather(valid_lat, valid_lon)
    end
  end
end
