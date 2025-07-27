require 'rails_helper'

RSpec.describe Weather, type: :model do
  let(:sample_current_weather) do
    {
      "name" => "New York",
      "main" => {
        "temp" => 22.5,
        "temp_min" => 18.0,
        "temp_max" => 25.0
      },
      "weather" => [
        {
          "description" => "partly cloudy"
        }
      ]
    }
  end

  let(:sample_forecast_data) do
    {
      current: sample_current_weather,
      forecast: {
        "list" => [
          {
            "dt_txt" => "2025-07-27 12:00:00",
            "main" => { "temp" => 24.0 },
            "weather" => [ { "description" => "sunny" } ]
          }
        ]
      },
      coordinates: {
        city: "New York"
      }
    }
  end

  # Stub Geocoder for all tests
  before do
    allow(Geocoder).to receive(:search).and_return([])
  end

  describe 'validations' do
    it 'requires address when zip_code is blank' do
      weather = Weather.new(address: nil, zip_code: nil)
      expect(weather).not_to be_valid
      expect(weather.errors[:address]).to include("can't be blank")
    end

    it 'requires zip_code when address is blank' do
      weather = Weather.new(address: nil, zip_code: nil)
      expect(weather).not_to be_valid
      expect(weather.errors[:zip_code]).to include("can't be blank")
    end

    it 'is valid with address' do
      weather = Weather.new(address: "123 Main St", zip_code: nil)
      expect(weather).to be_valid
    end

    it 'is valid with zip_code' do
      weather = Weather.new(address: nil, zip_code: "10001")
      expect(weather).to be_valid
    end

    it 'is valid with both address and zip_code' do
      weather = Weather.new(address: "123 Main St", zip_code: "10001")
      expect(weather).to be_valid
    end
  end

  describe 'initialization' do
    context 'with address and no coordinates' do
      it 'calls geocode_address' do
        # Stub Geocoder to prevent actual network calls
        allow(Geocoder).to receive(:search).and_return([])
        weather = Weather.new(address: "123 Main St")
        expect(weather.geocoding_error).to be_present
      end
    end

    context 'with coordinates' do
      it 'does not call geocode_address' do
        weather = Weather.new(address: "123 Main St", latitude: 40.7128, longitude: -74.0060)
        expect(weather.geocoding_error).to be_nil
      end
    end

    context 'with zip_code' do
      it 'does not call geocode_address' do
        weather = Weather.new(zip_code: "10001")
        expect(weather.geocoding_error).to be_nil
      end
    end
  end

  describe '#forecast_data' do
    it 'returns empty hash by default' do
      weather = Weather.new(zip_code: "10001")
      expect(weather.forecast_data).to eq({})
    end
  end

  describe '#set_forecast_data' do
    it 'sets forecast data' do
      weather = Weather.new(zip_code: "10001")
      weather.set_forecast_data(sample_forecast_data)
      expect(weather.forecast_data).to eq(sample_forecast_data)
    end
  end

  describe '#current_temperature' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'with valid forecast data' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns current temperature' do
        expect(weather.current_temperature).to eq(22.5)
      end
    end

    context 'with error in current data' do
      before do
        data = sample_forecast_data.dup
        data[:current] = { error: "API error" }
        weather.set_forecast_data(data)
      end

      it 'returns nil' do
        expect(weather.current_temperature).to be_nil
      end
    end

    context 'with invalid forecast data' do
      before do
        weather.set_forecast_data(error: "No data available")
      end

      it 'returns nil' do
        expect(weather.current_temperature).to be_nil
      end
    end

    context 'with no forecast data' do
      it 'returns nil' do
        expect(weather.current_temperature).to be_nil
      end
    end
  end

  describe '#high_low_temperature' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'with valid forecast data' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns high and low temperatures' do
        result = weather.high_low_temperature
        expect(result).to eq({ high: 25.0, low: 18.0 })
      end
    end

    context 'with error in current data' do
      before do
        data = sample_forecast_data.dup
        data[:current] = { error: "API error" }
        weather.set_forecast_data(data)
      end

      it 'returns nil' do
        expect(weather.high_low_temperature).to be_nil
      end
    end

    context 'with invalid forecast data' do
      before do
        weather.set_forecast_data(error: "No data available")
      end

      it 'returns nil' do
        expect(weather.high_low_temperature).to be_nil
      end
    end
  end

  describe '#weather_description' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'with valid forecast data' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns formatted weather description' do
        expect(WeatherDataProcessor).to receive(:format_weather_description)
          .with("partly cloudy")
          .and_return("Partly Cloudy")

        expect(weather.weather_description).to eq("Partly Cloudy")
      end
    end

    context 'with error in current data' do
      before do
        data = sample_forecast_data.dup
        data[:current] = { error: "API error" }
        weather.set_forecast_data(data)
      end

      it 'returns nil' do
        expect(weather.weather_description).to be_nil
      end
    end

    context 'with invalid forecast data' do
      before do
        weather.set_forecast_data(error: "No data available")
      end

      it 'returns nil' do
        expect(weather.weather_description).to be_nil
      end
    end
  end

  describe '#location_name' do
    let(:weather) { Weather.new(address: "San Francisco") }

    context 'with zip_code and coordinates data' do
      before do
        weather.zip_code = "94102"
        data = sample_forecast_data.dup
        data[:coordinates] = { city: "San Francisco" }
        weather.set_forecast_data(data)
      end

      it 'returns city from coordinates' do
        expect(weather.location_name).to eq("San Francisco")
      end
    end

    context 'with current weather data and no error' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns name from current weather data' do
        expect(weather.location_name).to eq("New York")
      end
    end

    context 'with current weather data but has error' do
      before do
        data = sample_forecast_data.dup
        data[:current] = { error: "API error" }
        weather.set_forecast_data(data)
      end

      it 'returns address' do
        expect(weather.location_name).to eq("San Francisco")
      end
    end

    context 'with no forecast data' do
      it 'returns address' do
        expect(weather.location_name).to eq("San Francisco")
      end
    end
  end

  describe '#from_cache?' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'when data is from cache' do
      before do
        data = sample_forecast_data.dup
        data[:from_cache] = true
        weather.set_forecast_data(data)
      end

      it 'returns true' do
        expect(weather.from_cache?).to be true
      end
    end

    context 'when data is not from cache' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns false' do
        expect(weather.from_cache?).to be false
      end
    end
  end

  describe '#has_error?' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'with geocoding error' do
      before do
        weather.instance_variable_set(:@geocoding_error, "Geocoding failed")
      end

      it 'returns true' do
        expect(weather.has_error?).to be true
      end
    end

    context 'with valid weather data' do
      before do
        allow(WeatherDataProcessor).to receive(:validate_weather_data)
          .with(sample_forecast_data)
          .and_return(true)
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns false' do
        expect(weather.has_error?).to be false
      end
    end

    context 'with invalid weather data' do
      before do
        allow(WeatherDataProcessor).to receive(:validate_weather_data)
          .with(sample_forecast_data)
          .and_return(false)
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns true' do
        expect(weather.has_error?).to be true
      end
    end
  end

  describe '#error_message' do
    let(:weather) { Weather.new(zip_code: "10001") }

    context 'with geocoding error' do
      before do
        weather.instance_variable_set(:@geocoding_error, "Geocoding failed")
      end

      it 'returns geocoding error' do
        expect(weather.error_message).to eq("Geocoding failed")
      end
    end

    context 'with forecast data error' do
      before do
        weather.set_forecast_data(error: "API error")
      end

      it 'returns forecast error' do
        expect(weather.error_message).to eq("API error")
      end
    end

    context 'with current data error' do
      before do
        data = sample_forecast_data.dup
        data[:current] = { error: "Current weather error" }
        weather.set_forecast_data(data)
      end

      it 'returns current data error' do
        expect(weather.error_message).to eq("Current weather error")
      end
    end

    context 'with forecast list error' do
      before do
        data = sample_forecast_data.dup
        data[:forecast] = { error: "Forecast list error" }
        weather.set_forecast_data(data)
      end

      it 'returns forecast list error' do
        expect(weather.error_message).to eq("Forecast list error")
      end
    end

    context 'with no errors' do
      before do
        weather.set_forecast_data(sample_forecast_data)
      end

      it 'returns nil' do
        expect(weather.error_message).to be_nil
      end
    end
  end

  describe '#extended_forecast' do
    let(:weather) { Weather.new(zip_code: "10001") }

    before do
      weather.set_forecast_data(sample_forecast_data)
    end

    it 'delegates to WeatherDataProcessor' do
      expected_result = [ { date: "Today", temp: "24°C" } ]
      expect(WeatherDataProcessor).to receive(:process_extended_forecast)
        .with(sample_forecast_data)
        .and_return(expected_result)

      expect(weather.extended_forecast).to eq(expected_result)
    end
  end

  describe '#to_json' do
    let(:weather) do
      Weather.new(
        address: "123 Main St",
        zip_code: "10001",
        latitude: 40.7128,
        longitude: -74.0060
      )
    end

    before do
      weather.set_forecast_data(sample_forecast_data)
    end

    it 'returns JSON representation' do
      result = JSON.parse(weather.to_json)

      expect(result).to include(
        "address" => "123 Main St",
        "zip_code" => "10001",
        "latitude" => 40.7128,
        "longitude" => -74.0060,
        "forecast_data" => hash_including(
          "current" => hash_including("name" => "New York")
        )
      )
    end
  end

  describe '.from_json' do
    let(:json_data) do
      {
        "address" => "123 Main St",
        "zip_code" => "10001",
        "latitude" => 40.7128,
        "longitude" => -74.0060,
        "forecast_data" => {
          "current" => sample_current_weather,
          "from_cache" => false
        }
      }.to_json
    end

    it 'creates Weather instance from JSON' do
      weather = Weather.from_json(json_data)

      expect(weather.address).to eq("123 Main St")
      expect(weather.zip_code).to eq("10001")
      expect(weather.latitude).to eq(40.7128)
      expect(weather.longitude).to eq(-74.0060)
      expect(weather.forecast_data[:current]).to include(name: "New York")
    end

    it 'symbolizes forecast data keys' do
      weather = Weather.from_json(json_data)
      expect(weather.forecast_data).to have_key(:current)
      expect(weather.forecast_data).to have_key(:from_cache)
    end

    context 'without forecast data' do
      let(:json_data_without_forecast) do
        {
          "address" => "123 Main St",
          "zip_code" => "10001",
          "latitude" => 40.7128,
          "longitude" => -74.0060
        }.to_json
      end

      it 'creates Weather instance without forecast data' do
        weather = Weather.from_json(json_data_without_forecast)

        expect(weather.address).to eq("123 Main St")
        expect(weather.forecast_data).to eq({})
      end
    end
  end

  describe '#geocode_address' do
    let(:weather) { Weather.allocate } # Don't call initialize
    let(:mock_result) { double('result', latitude: 40.7128, longitude: -74.0060) }

    context 'when geocoding is successful' do
      before do
        allow(Geocoder).to receive(:search).with("123 Main St").and_return([ mock_result ])
        weather.send(:initialize, address: "123 Main St")
      end

      it 'sets latitude and longitude' do
        expect(weather.latitude).to eq(40.7128)
        expect(weather.longitude).to eq(-74.0060)
      end

      it 'does not set geocoding error' do
        expect(weather.geocoding_error).to be_nil
      end
    end

    context 'when no results are found' do
      before do
        allow(Geocoder).to receive(:search).with("123 Main St").and_return([])
        weather.send(:initialize, address: "123 Main St")
      end

      it 'sets geocoding error' do
        expect(weather.geocoding_error).to eq("Unable to find location for '123 Main St'. Please try a different address or zip code.")
      end

      it 'does not set coordinates' do
        expect(weather.latitude).to be_nil
        expect(weather.longitude).to be_nil
      end
    end

    context 'when geocoding raises an exception' do
      before do
        allow(Geocoder).to receive(:search).and_raise(StandardError.new("Network error"))
        allow(Rails.logger).to receive(:error)
        weather.send(:initialize, address: "123 Main St")
      end

      it 'sets geocoding error' do
        expect(weather.geocoding_error).to eq("Unable to find location for '123 Main St'. Please try a different address or zip code.")
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with("Geocoding failed for address '123 Main St': Network error")
        weather.send(:initialize, address: "123 Main St")
      end

      it 'does not set coordinates' do
        expect(weather.latitude).to be_nil
        expect(weather.longitude).to be_nil
      end
    end

    context 'when address is blank' do
      before do
        weather.send(:initialize, address: nil)
      end

      it 'does not call Geocoder' do
        expect(Geocoder).not_to receive(:search)
        weather.send(:geocode_address)
      end
    end
  end

  describe 'private methods' do
    let(:weather) { build(:weather) }

    describe '#should_geocode?' do
      context 'with address and no coordinates' do
        before do
          weather.address = "123 Main St"
          weather.latitude = nil
          weather.longitude = nil
        end

        it 'returns true' do
          expect(weather.send(:should_geocode?)).to be true
        end
      end

      context 'with address and coordinates' do
        before do
          weather.address = "123 Main St"
          weather.latitude = 40.7128
          weather.longitude = -74.0060
        end

        it 'returns false' do
          expect(weather.send(:should_geocode?)).to be false
        end
      end

      context 'without address' do
        before do
          weather.address = nil
        end

        it 'returns false' do
          expect(weather.send(:should_geocode?)).to be false
        end
      end
    end

    describe '#valid_forecast_data?' do
      context 'with valid current data and no error' do
        before do
          weather.set_forecast_data(sample_forecast_data)
        end

        it 'returns true' do
          expect(weather.send(:valid_forecast_data?)).to be true
        end
      end

      context 'with error in forecast data' do
        before do
          weather.set_forecast_data(error: "API error")
        end

        it 'returns false' do
          expect(weather.send(:valid_forecast_data?)).to be false
        end
      end

      context 'with current data' do
        before do
          weather.set_forecast_data(current: sample_current_weather)
        end

        it 'returns true' do
          expect(weather.send(:valid_forecast_data?)).to be true
        end
      end
    end
  end
end
