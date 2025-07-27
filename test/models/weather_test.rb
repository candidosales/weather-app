require "test_helper"

class WeatherTest < ActiveSupport::TestCase
  test "should be valid with address" do
    weather = Weather.new(address: "New York, NY")
    assert weather.valid?
  end

  test "should be valid with zip code" do
    weather = Weather.new(zip_code: "10001")
    assert weather.valid?
  end

  test "should be invalid without address or zip code" do
    weather = Weather.new
    assert_not weather.valid?
  end

  test "should not be valid with both address and zip code blank" do
    weather = Weather.new(address: "", zip_code: "")
    assert_not weather.valid?
  end

  test "current_temperature returns nil when no data" do
    weather = Weather.new(zip_code: "00000")

    # Mock the service to return an error
    WeatherService.any_instance.stubs(:get_weather_by_zip).returns({ error: "Not found" })

    assert_nil weather.current_temperature
  end

  test "from_cache? returns true when data is from cache" do
    weather = Weather.new(zip_code: "10001")

    # Mock the service to return cached data
    WeatherService.any_instance.stubs(:get_weather_by_zip).returns({
      current: { "main" => { "temp" => 22.0 } },
      from_cache: true
    })

    assert weather.from_cache?
  end
end
