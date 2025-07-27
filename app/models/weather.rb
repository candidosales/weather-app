class Weather
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :address, :string
  attribute :zip_code, :string
  attribute :latitude, :float
  attribute :longitude, :float

  validates :address, presence: true, if: -> { zip_code.blank? }
  validates :zip_code, presence: true, if: -> { address.blank? }

  def initialize(attributes = {})
    super(attributes)
    geocode_address if should_geocode?
  end

  def forecast_data
    @forecast_data ||= {}
  end

  def set_forecast_data(data)
    @forecast_data = data
  end

  def current_temperature
    return nil unless valid_forecast_data?

    current_data = forecast_data[:current]
    return nil if current_data[:error]

    current_data.dig("main", "temp")
  end

  def high_low_temperature
    return nil unless valid_forecast_data?

    current_data = forecast_data[:current]
    return nil if current_data[:error]

    {
      high: current_data.dig("main", "temp_max"),
      low: current_data.dig("main", "temp_min")
    }
  end

  def weather_description
    return nil unless valid_forecast_data?

    current_data = forecast_data[:current]
    return nil if current_data[:error]

    WeatherDataProcessor.format_weather_description(
      current_data.dig("weather", 0, "description")
    )
  end

  def location_name
    return forecast_data.dig(:coordinates, :city) if zip_code.present? && forecast_data[:coordinates]
    return forecast_data.dig(:current, "name") if forecast_data[:current] && !forecast_data[:current][:error]

    address
  end

  def from_cache?
    forecast_data[:from_cache] == true
  end

  def has_error?
    return true if geocoding_error.present?
    !WeatherDataProcessor.validate_weather_data(forecast_data)
  end

  def error_message
    return geocoding_error if geocoding_error.present?
    return forecast_data[:error] if forecast_data[:error].present?
    return forecast_data[:current][:error] if forecast_data[:current] && forecast_data[:current][:error].present?
    return forecast_data[:forecast][:error] if forecast_data[:forecast] && forecast_data[:forecast][:error].present?
    nil
  end

  def extended_forecast
    WeatherDataProcessor.process_extended_forecast(forecast_data)
  end

  def to_json(options = {})
    {
      address: address,
      zip_code: zip_code,
      latitude: latitude,
      longitude: longitude,
      forecast_data: @forecast_data
    }.to_json
  end

  def self.from_json(json_string)
    data = JSON.parse(json_string)
    weather = new(
      address: data["address"],
      zip_code: data["zip_code"],
      latitude: data["latitude"],
      longitude: data["longitude"]
    )
    if data["forecast_data"]
      forecast_data = data["forecast_data"]
      # Convert string keys to symbols recursively
      symbolized_data = forecast_data.is_a?(Hash) ? forecast_data.deep_symbolize_keys : forecast_data
      weather.instance_variable_set(:@forecast_data, symbolized_data)
    end
    weather
  end

  def geocoding_error
    @geocoding_error
  end

  private

  def should_geocode?
    address.present? && latitude.blank? && longitude.blank?
  end

  def valid_forecast_data?
    !forecast_data[:error] || forecast_data[:current]
  end

  def geocode_address
    return if address.blank?

    begin
      results = Geocoder.search(address)

      if results.empty?
        @geocoding_error = "Unable to find location for '#{address}'. Please try a different address or zip code."
        return
      end

      result = results.first
      self.latitude = result.latitude
      self.longitude = result.longitude
    rescue => e
      Rails.logger.error "Geocoding failed for address '#{address}': #{e.message}"
      # Set error state so the controller can handle it
      @geocoding_error = "Unable to find location for '#{address}'. Please try a different address or zip code."
    end
  end
end
