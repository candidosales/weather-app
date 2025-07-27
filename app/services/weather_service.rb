class WeatherService
  include HTTParty

  # Using OpenWeatherMap API
  BASE_URL = "https://api.openweathermap.org/data/2.5".freeze
  CACHE_EXPIRY = WeatherConfig.cache_expiry.freeze
  REQUEST_TIMEOUT = WeatherConfig.request_timeout.freeze

  # HTTParty configuration
  base_uri BASE_URL
  default_timeout REQUEST_TIMEOUT
  headers "User-Agent" => "WeatherApp/1.0"

  class << self
    def api_key
      @api_key ||= begin
        key = Rails.application.credentials.openweather_api_key || ENV["OPENWEATHER_API_KEY"]
        raise ApiKeyError, "OpenWeather API key not configured" if key.blank?
        key
      end
    end
  end

  # Custom error classes
  class ApiKeyError < StandardError; end
  class ApiError < StandardError; end
  class InvalidLocationError < StandardError; end
  class UnexpectedError < StandardError; end

  # Public methods to get weather data
  def get_current_weather(lat, lon)
    validate_coordinates!(lat, lon)
    cache_key = "weather_current_#{lat}_#{lon}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      make_api_request("/weather", lat: lat, lon: lon)
    end
  end

  def get_forecast(lat, lon)
    validate_coordinates!(lat, lon)
    cache_key = "weather_forecast_#{lat}_#{lon}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      make_api_request("/forecast", lat: lat, lon: lon)
    end
  end

  def get_weather_by_zip(zip_code)
    validate_zip_code!(zip_code)
    cache_key = "weather_zip_#{zip_code}"

    # Check if data exists in cache before fetch
    cached_data = Rails.cache.read(cache_key)

    if cached_data
      # Return cached data with from_cache flag set to true
      cached_data = cached_data.dup
      cached_data[:from_cache] = true
      return cached_data
    end

    # If not in cache, fetch fresh data
    coordinates = get_coordinates_from_zip(zip_code)

    current_weather = get_current_weather(coordinates[:lat], coordinates[:lon])
    forecast = get_forecast(coordinates[:lat], coordinates[:lon])

    result = {
      current: current_weather,
      forecast: forecast,
      coordinates: coordinates,
      from_cache: false
    }

    # Store in cache
    Rails.cache.write(cache_key, result, expires_in: CACHE_EXPIRY)
    result
  rescue InvalidLocationError => e
    log_error("Failed to get weather by zip code #{zip_code}", e)
    { error: e.message }
  rescue => e
    log_error("Unexpected error getting weather by zip code #{zip_code}", e)
    { error: "Weather service temporarily unavailable" }
  end

  private

  def validate_coordinates!(lat, lon)
    lat_f = lat.to_f
    lon_f = lon.to_f

    unless lat_f.between?(-90, 90) && lon_f.between?(-180, 180)
      raise InvalidLocationError, "Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180"
    end
  end

  def validate_zip_code!(zip_code)
    if zip_code.blank? || zip_code.to_s.strip.empty?
      raise InvalidLocationError, "Zip code cannot be blank"
    end
  end

  def make_api_request(endpoint, **params)
    query_params = {
      appid: self.class.api_key,
      units: "metric"
    }.merge(params)

    response = self.class.get(endpoint, query: query_params)
    log_api_call(endpoint, query_params, response.code)
    handle_response(response)
  end

  def get_coordinates_from_zip(zip_code)
    results = Geocoder.search(zip_code)

    if results.empty?
      raise InvalidLocationError, "Location not found for zip code: #{zip_code}"
    end

    result = results.first
    {
      lat: result.latitude,
      lon: result.longitude,
      city: result.city,
      state: result.state,
      country: result.country
    }
  end

  def handle_response(response)
    case response.code
    when 200
      response.parsed_response
    when 401
      raise ApiError, "Invalid API key"
    when 404
      raise ApiError, "Location not found"
    when 429
      raise ApiError, "API rate limit exceeded. Please try again later"
    when 500..599
      # Treat server errors as API errors
      raise ApiError, "API Error: #{response.code} - Service unavailable"
    else
      raise ApiError, "API Error: #{response.code} - #{response.message}"
    end
  end

  def log_error(message, exception)
    Rails.logger.error "#{self.class.name}: #{message} - #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if WeatherConfig.enable_detailed_logging?
  end

  def log_api_call(endpoint, params, response_code)
    Rails.logger.info({
      event: "api_call",
      service: "openweather",
      endpoint: endpoint,
      params: params.except(:appid), # Don't log API keys
      response_code: response_code,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
