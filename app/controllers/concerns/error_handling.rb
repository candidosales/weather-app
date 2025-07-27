module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from WeatherService::ApiError, with: :handle_api_error
    rescue_from WeatherService::InvalidLocationError, with: :handle_location_error
    rescue_from WeatherService::ApiKeyError, with: :handle_configuration_error
  end

  private

  def handle_api_error(exception)
    log_error(exception)
    render_error_response(exception.message, :service_unavailable)
  end

  def handle_location_error(exception)
    log_error(exception)
    render_error_response(exception.message, :bad_request)
  end

  def handle_configuration_error(exception)
    log_error(exception)
    render_error_response("Service configuration error. Please contact support.", :internal_server_error)
  end

  def log_error(exception)
    Rails.logger.error "#{self.class.name}: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if Rails.env.development?
  end

  def render_error_response(message, status)
    respond_to do |format|
      format.html do
        flash[:alert] = message
        redirect_to root_path and return
      end
      format.json { render json: { error: message }, status: status }
    end
  end
end
