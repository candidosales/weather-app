class WeatherOrchestrator
  def initialize(weather_params)
    @weather = Weather.new(weather_params)
    @weather_service = WeatherService.new
  end

  def call
    validate_input
    return { weather: @weather, error: @weather.errors.full_messages.join(", ") } unless @weather.valid?
    return { weather: @weather, error: @weather.geocoding_error } if @weather.geocoding_error.present?

    forecast_data = fetch_forecast_data
    @weather.set_forecast_data(forecast_data)

    { weather: @weather, error: nil }
  rescue StandardError => e
    Rails.logger.error "WeatherOrchestrator error: #{e.message}"
    { weather: @weather, error: "Weather service temporarily unavailable" }
  end

  private

  def validate_input
    errors = WeatherValidator.validate_location_input(
      address: @weather.address,
      zip_code: @weather.zip_code,
      latitude: @weather.latitude,
      longitude: @weather.longitude
    )

    errors.each { |error| @weather.errors.add(:base, error) }
  end

  def fetch_forecast_data
    if @weather.zip_code.present?
      fetch_weather_by_zip
    elsif @weather.latitude.present? && @weather.longitude.present?
      fetch_weather_by_coordinates
    else
      { error: "No valid location provided" }
    end
  end

  def fetch_weather_by_zip
    @weather_service.get_weather_by_zip(@weather.zip_code)
  rescue WeatherService::InvalidLocationError => e
    Rails.logger.error "Invalid location for zip code #{@weather.zip_code}: #{e.message}"
    { error: e.message }
  rescue StandardError => e
    Rails.logger.error "Weather service error for zip code #{@weather.zip_code}: #{e.message}"
    { error: "Weather service temporarily unavailable" }
  end

  def fetch_weather_by_coordinates
    {
      current: @weather_service.get_current_weather(@weather.latitude, @weather.longitude),
      forecast: @weather_service.get_forecast(@weather.latitude, @weather.longitude),
      from_cache: Rails.cache.exist?("weather_current_#{@weather.latitude}_#{@weather.longitude}")
    }
  rescue StandardError => e
    Rails.logger.error "Weather service error for coordinates (#{@weather.latitude}, #{@weather.longitude}): #{e.message}"
    { error: "Weather service temporarily unavailable" }
  end
end
