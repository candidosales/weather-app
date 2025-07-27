# Weather Application Configuration
module WeatherConfig
  class << self
    def cache_expiry
      case Rails.env
      when "development"
        5.minutes
      when "test"
        1.minute
      else
        30.minutes
      end
    end

    def request_timeout
      case Rails.env
      when "development"
        15.seconds
      when "test"
        5.seconds
      else
        10.seconds
      end
    end

    def log_level
      case Rails.env
      when "development"
        :debug
      when "test"
        :warn
      else
        :info
      end
    end

    def enable_detailed_logging?
      Rails.env.development? || Rails.env.test?
    end

    def max_retries
      case Rails.env
      when "development"
        1
      when "test"
        0
      else
        3
      end
    end

    def rate_limit_enabled?
      Rails.env.production?
    end

    def rate_limit_requests
      case Rails.env
      when "production"
        100 # requests per hour
      else
        1000 # higher limit for development
      end
    end

    def rate_limit_window
      1.hour
    end
  end
end
