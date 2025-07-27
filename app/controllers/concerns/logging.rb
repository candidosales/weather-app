module Logging
  extend ActiveSupport::Concern

  included do
    after_action :log_request_completion
  end

  private

  def log_request_completion
    Rails.logger.info build_request_log_message
  end

  def build_request_log_message
    {
      timestamp: Time.current.iso8601,
      method: request.method,
      path: request.path,
      status: response.status,
      user_agent: request.user_agent,
      ip: request.remote_ip,
      params: sanitized_params,
      duration: request_duration
    }.to_json
  end

  def sanitized_params
    # Remove sensitive information from logs
    safe_params = params.except(:controller, :action, :format)
    safe_params[:weather] = safe_params[:weather]&.except(:password, :api_key) if safe_params[:weather]
    safe_params
  end

  def request_duration
    @request_start_time ||= Time.current
    ((Time.current - @request_start_time) * 1000).round(2)
  end

  def log_weather_request(location_type, location_value, success: true, error: nil)
    Rails.logger.info({
      event: "weather_request",
      location_type: location_type,
      location_value: location_value,
      success: success,
      error: error&.message,
      timestamp: Time.current.iso8601
    }.to_json)
  end

  def log_cache_hit(cache_key)
    Rails.logger.debug "Cache hit for key: #{cache_key}"
  end

  def log_cache_miss(cache_key)
    Rails.logger.debug "Cache miss for key: #{cache_key}"
  end

  def log_api_call(endpoint, params, response_code)
    Rails.logger.info({
      event: "api_call",
      endpoint: endpoint,
      params: params.except(:appid), # Don't log API keys
      response_code: response_code,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
