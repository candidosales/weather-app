class WeatherController < ApplicationController
  include ErrorHandling
  include InputValidation
  include Logging
  def index
    @weather = Weather.new
  end

  def create
    log_weather_request_start

    orchestrator = WeatherOrchestrator.new(weather_params)
    result = orchestrator.call

    @weather = result[:weather]

    if result[:error].present?
      log_weather_request_failure(result[:error])
      flash[:alert] = result[:error]
      redirect_to root_path and return
    end

    if @weather.has_error?
      log_weather_request_failure(@weather.error_message)
      flash[:alert] = @weather.error_message
      redirect_to root_path and return
    end

    # Success - render the show view directly with forecast data
    log_weather_request_success
    flash.now[:notice] = "Weather data retrieved from cache." if @weather.from_cache?
    render :show
  end

  private

  def weather_params
    params.require(:weather).permit(:address, :zip_code)
  end

  def log_weather_request_start
    location_type = weather_params[:zip_code].present? ? "zip_code" : "address"
    location_value = weather_params[:zip_code] || weather_params[:address]
    log_weather_request(location_type, location_value)
  end

  def log_weather_request_success
    Rails.logger.info "Weather request completed successfully"
  end

  def log_weather_request_failure(error_message)
    Rails.logger.error "Weather request failed: #{error_message}"
  end
end
