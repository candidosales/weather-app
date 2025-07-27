module InputValidation
  extend ActiveSupport::Concern

  included do
    before_action :sanitize_inputs, only: [ :create ]
  end

  private

  def sanitize_inputs
    params[:weather]&.transform_values! { |value| sanitize_value(value) }
  end

  def sanitize_value(value)
    return nil if value.blank?

    # Remove potentially dangerous characters and normalize whitespace
    sanitized = value.to_s.strip
      .gsub(/[<>]/, "") # Remove potential HTML tags
      .gsub(/[^\w\s\-.,]/, "") # Allow only alphanumeric, spaces, hyphens, commas, periods
      .gsub(/\s+/, " ") # Normalize whitespace

    sanitized.presence
  end

  def validate_zip_code(zip_code)
    return false if zip_code.blank?

    # US zip code validation (5 digits or 5+4 format)
    zip_code.to_s.match?(/^\d{5}(-\d{4})?$/)
  end

  def validate_address(address)
    return false if address.blank?

    # Basic address validation - should contain at least 3 characters
    # and not be just numbers
    address.to_s.length >= 3 && !address.to_s.match?(/^\d+$/)
  end

  def validate_coordinates(lat, lon)
    lat_f = lat.to_f
    lon_f = lon.to_f

    lat_f.between?(-90, 90) && lon_f.between?(-180, 180)
  end
end
