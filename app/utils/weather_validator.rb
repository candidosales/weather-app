class WeatherValidator
  class << self
    def validate_location_input(address: nil, zip_code: nil, latitude: nil, longitude: nil)
      errors = []

      if address.blank? && zip_code.blank? && (latitude.blank? || longitude.blank?)
        errors << "Please provide either an address, zip code, or coordinates"
      end

      if address.present? && !valid_address?(address)
        errors << "Please provide a valid address"
      end

      if zip_code.present? && !valid_zip_code?(zip_code)
        errors << "Please provide a valid zip code"
      end

      if latitude.present? && longitude.present? && !valid_coordinates?(latitude, longitude)
        errors << "Please provide valid coordinates"
      end

      errors
    end

    def valid_address?(address)
      return false if address.blank?

      # Basic address validation
      address.to_s.strip.length >= 3 &&
        !address.to_s.match?(/^\d+$/) && # Not just numbers
        address.to_s.match?(/[a-zA-Z]/) # Contains letters
    end

    def valid_zip_code?(zip_code)
      return false if zip_code.blank?

      # US zip code validation (5 digits or 5+4 format)
      zip_code.to_s.strip.match?(/^\d{5}(-\d{4})?$/)
    end

    def valid_coordinates?(latitude, longitude)
      return false if latitude.nil? || longitude.nil?

      lat_f = latitude.to_f
      lon_f = longitude.to_f

      lat_f.between?(-90, 90) && lon_f.between?(-180, 180)
    end

    def sanitize_location_input(input)
      return nil if input.blank?

      sanitized = input.to_s.strip
        .gsub(/<script[^>]*>.*?<\/script>/i, "") # Remove script tags and their content
        .gsub(/<[^>]*>/, "") # Remove remaining HTML tags
        .gsub(/[^\w\s\-.,]/, "") # Allow only alphanumeric, spaces, hyphens, commas, periods
        .gsub(/\s+/, " ") # Normalize whitespace
        .strip # Remove leading/trailing whitespace

      sanitized.presence
    end

    def validate_weather_data(data)
      return false if data.blank?
      return false if data[:error].present?
      return false if data[:current] && data[:current][:error].present?
      return false if data[:forecast] && data[:forecast][:error].present?
      true
    end
  end
end
