require 'rails_helper'

RSpec.describe WeatherDataProcessor do
  describe '.process_extended_forecast' do
    let(:valid_forecast_data) do
      {
        forecast: {
          "list" => [
            {
              "dt_txt" => "2024-01-01 12:00:00",
              "main" => { "temp" => 20.5 },
              "weather" => [ { "description" => "clear sky", "id" => 800 } ]
            },
            {
              "dt_txt" => "2024-01-01 15:00:00",
              "main" => { "temp" => 25.0 },
              "weather" => [ { "description" => "clear sky", "id" => 800 } ]
            },
            {
              "dt_txt" => "2024-01-02 12:00:00",
              "main" => { "temp" => 18.0 },
              "weather" => [ { "description" => "rain", "id" => 500 } ]
            }
          ]
        }
      }
    end

    context 'with valid forecast data' do
      it 'processes and formats the forecast correctly' do
        result = described_class.process_extended_forecast(valid_forecast_data)

        expect(result).to be_an(Array)
        expect(result.length).to be <= 5
        expect(result.first).to include(:date, :high, :low, :description)
      end

      it 'calculates daily high and low temperatures' do
        result = described_class.process_extended_forecast(valid_forecast_data)
        first_day = result.first

        expect(first_day[:high]).to eq(25)
        expect(first_day[:low]).to eq(21)
      end
    end

    context 'with error in forecast data' do
      it 'returns empty array when forecast has error' do
        data_with_error = { forecast: { error: "API error" } }
        result = described_class.process_extended_forecast(data_with_error)
        expect(result).to eq([])
      end

      it 'returns empty array when main data has error' do
        data_with_error = { error: "API error" }
        result = described_class.process_extended_forecast(data_with_error)
        expect(result).to eq([])
      end
    end

    context 'with empty forecast data' do
      it 'returns empty array for nil data' do
        result = described_class.process_extended_forecast(nil)
        expect(result).to eq([])
      end

      it 'returns empty array for empty data' do
        result = described_class.process_extended_forecast({})
        expect(result).to eq([])
      end
    end
  end

  describe '.format_temperature' do
    it 'formats metric temperature correctly' do
      expect(described_class.format_temperature(20.5, 'metric')).to eq('21°C')
    end

    it 'formats imperial temperature correctly' do
      expect(described_class.format_temperature(68.0, 'imperial')).to eq('68°F')
    end

    it 'handles nil temperature' do
      expect(described_class.format_temperature(nil)).to be_nil
    end

    it 'uses metric as default' do
      expect(described_class.format_temperature(20.5)).to eq('21°C')
    end
  end

  describe '.format_weather_description' do
    it 'formats description correctly' do
      expect(described_class.format_weather_description('clear sky')).to eq('Clear Sky')
    end

    it 'handles nil description' do
      expect(described_class.format_weather_description(nil)).to be_nil
    end

    it 'handles empty description' do
      expect(described_class.format_weather_description('')).to be_nil
    end
  end

  describe '.validate_weather_data' do
    it 'returns true for valid data' do
      valid_data = { current: { "main" => { "temp" => 20 } } }
      expect(described_class.validate_weather_data(valid_data)).to be true
    end

    it 'returns false for data with error' do
      invalid_data = { error: "API error" }
      expect(described_class.validate_weather_data(invalid_data)).to be false
    end

    it 'returns false for nil data' do
      expect(described_class.validate_weather_data(nil)).to be false
    end
  end
end
