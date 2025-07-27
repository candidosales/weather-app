# Geocoder configuration
Geocoder.configure(
  # Use a specific geocoding service (optional, defaults to Google)
  lookup: :nominatim,

  # Set timeout for geocoding requests
  timeout: 10,

  # Set units for distance calculations
  units: :km,

  # Use HTTPS
  use_https: true,

  # Cache geocoding results
  cache: Rails.cache,
  cache_prefix: "geocoder:",

  # Set the cache options
  cache_options: {
    expiration: 1.day,
    race_condition_ttl: 10.seconds
  },

  # Nominatim specific configuration
  nominatim: {
    host: "nominatim.openstreetmap.org",
    format: "json"
  },

  # Add User-Agent header to avoid getting blocked
  http_headers: {
    "User-Agent" => "WeatherApp/1.0 (weather-app)"
  }
)
