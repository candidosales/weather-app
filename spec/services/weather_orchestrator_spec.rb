require 'rails_helper'

RSpec.describe WeatherOrchestrator do
  let(:weather_params) { { address: "New York, NY" } }
  let(:orchestrator) { described_class.new(weather_params) }

  describe '#call' do
    context 'with valid parameters' do
      before do
        # Stub geocoding to return valid coordinates
        allow(Geocoder).to receive(:search).with("New York, NY").and_return([
          double(latitude: 40.7128, longitude: -74.0060)
        ])
        allow_any_instance_of(WeatherService).to receive(:get_current_weather).and_return({ "main" => { "temp" => 20 } })
        allow_any_instance_of(WeatherService).to receive(:get_forecast).and_return({ "list" => [] })
        allow(Rails.cache).to receive(:exist?).and_return(false)
      end

      it 'returns weather object with forecast data' do
        result = orchestrator.call

        expect(result[:weather]).to be_a(Weather)
        expect(result[:error]).to be_nil
        expect(result[:weather].forecast_data).to include(:current, :forecast)
      end
    end

    context 'with invalid parameters' do
      let(:weather_params) { { address: "", zip_code: "" } }

      it 'returns error message' do
        result = orchestrator.call

        expect(result[:weather]).to be_a(Weather)
        expect(result[:error]).to include("Address can't be blank")
      end
    end

    context 'with geocoding error' do
      let(:weather_params) { { address: "Invalid Address 12345" } }

      before do
        allow(Geocoder).to receive(:search).and_return([])
      end

      it 'returns geocoding error' do
        result = orchestrator.call

        expect(result[:weather]).to be_a(Weather)
        expect(result[:error]).to include("Unable to find location")
      end
    end
  end
end
