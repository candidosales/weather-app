require 'rails_helper'

RSpec.describe WeatherValidator do
  describe '.validate_location_input' do
    context 'with valid inputs' do
      it 'returns empty errors for valid address' do
        errors = described_class.validate_location_input(address: 'New York, NY')
        expect(errors).to be_empty
      end

      it 'returns empty errors for valid zip code' do
        errors = described_class.validate_location_input(zip_code: '10001')
        expect(errors).to be_empty
      end

      it 'returns empty errors for valid coordinates' do
        errors = described_class.validate_location_input(latitude: 40.7128, longitude: -74.0060)
        expect(errors).to be_empty
      end
    end

    context 'with invalid inputs' do
      it 'returns error when no location provided' do
        errors = described_class.validate_location_input
        expect(errors).to include('Please provide either an address, zip code, or coordinates')
      end

      it 'returns error for invalid address' do
        errors = described_class.validate_location_input(address: '12')
        expect(errors).to include('Please provide a valid address')
      end

      it 'returns error for invalid zip code' do
        errors = described_class.validate_location_input(zip_code: '123')
        expect(errors).to include('Please provide a valid zip code')
      end

      it 'returns error for invalid coordinates' do
        errors = described_class.validate_location_input(latitude: 100, longitude: 200)
        expect(errors).to include('Please provide valid coordinates')
      end
    end
  end

  describe '.valid_address?' do
    it 'returns true for valid address' do
      expect(described_class.valid_address?('New York, NY')).to be true
    end

    it 'returns false for short address' do
      expect(described_class.valid_address?('NY')).to be false
    end

    it 'returns false for numbers only' do
      expect(described_class.valid_address?('12345')).to be false
    end

    it 'returns false for nil address' do
      expect(described_class.valid_address?(nil)).to be false
    end

    it 'returns false for empty address' do
      expect(described_class.valid_address?('')).to be false
    end
  end

  describe '.valid_zip_code?' do
    it 'returns true for valid 5-digit zip' do
      expect(described_class.valid_zip_code?('10001')).to be true
    end

    it 'returns true for valid 9-digit zip' do
      expect(described_class.valid_zip_code?('10001-1234')).to be true
    end

    it 'returns false for invalid zip' do
      expect(described_class.valid_zip_code?('123')).to be false
    end

    it 'returns false for nil zip' do
      expect(described_class.valid_zip_code?(nil)).to be false
    end

    it 'returns false for empty zip' do
      expect(described_class.valid_zip_code?('')).to be false
    end
  end

  describe '.valid_coordinates?' do
    it 'returns true for valid coordinates' do
      expect(described_class.valid_coordinates?(40.7128, -74.0060)).to be true
    end

    it 'returns false for invalid latitude' do
      expect(described_class.valid_coordinates?(100, -74.0060)).to be false
    end

    it 'returns false for invalid longitude' do
      expect(described_class.valid_coordinates?(40.7128, 200)).to be false
    end

    it 'returns false for nil coordinates' do
      expect(described_class.valid_coordinates?(nil, -74.0060)).to be false
    end
  end

  describe '.sanitize_location_input' do
    it 'sanitizes input correctly' do
      expect(described_class.sanitize_location_input('New York, NY')).to eq('New York, NY')
    end

    it 'removes HTML tags' do
      expect(described_class.sanitize_location_input('<script>alert("xss")</script>New York')).to eq('New York')
    end

    it 'removes special characters' do
      expect(described_class.sanitize_location_input('New York!!!')).to eq('New York')
    end

    it 'normalizes whitespace' do
      expect(described_class.sanitize_location_input('  New   York  ')).to eq('New York')
    end

    it 'returns nil for blank input' do
      expect(described_class.sanitize_location_input('')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.sanitize_location_input(nil)).to be_nil
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
