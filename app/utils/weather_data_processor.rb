class WeatherDataProcessor
  class << self
    def process_extended_forecast(forecast_data)
      return [] if forecast_data.nil? || forecast_data[:error] || !forecast_data[:forecast]

      forecast_list = forecast_data[:forecast]
      return [] if forecast_list[:error]

      daily_forecasts = group_forecast_by_date(forecast_list)
      format_daily_forecasts(daily_forecasts)
    end

    def format_temperature(temp, unit = "metric")
      return nil if temp.nil?

      case unit
      when "metric"
        "#{temp.round}°C"
      when "imperial"
        "#{temp.round}°F"
      else
        "#{temp.round}°C"
      end
    end

    def format_weather_description(description)
      return nil if description.blank?
      description.to_s.titleize
    end

    def validate_weather_data(data)
      return false if data.blank?
      return false if data[:error].present?
      return false if data[:current] && data[:current][:error].present?
      return false if data[:forecast] && data[:forecast][:error].present?
      true
    end

    private

    def group_forecast_by_date(forecast_list)
      daily_forecasts = {}

      forecast_list["list"]&.each do |item|
        date = Date.parse(item["dt_txt"]).strftime("%A, %B %d")
        temp = item.dig("main", "temp")
        description = item.dig("weather", 0, "description")
        weather_code = item.dig("weather", 0, "id")

        if daily_forecasts[date]
          daily_forecasts[date][:temps] << temp
          daily_forecasts[date][:descriptions] << description
          daily_forecasts[date][:weather_codes] << weather_code
        else
          daily_forecasts[date] = {
            date: date,
            temps: [ temp ],
            descriptions: [ description ],
            weather_codes: [ weather_code ]
          }
        end
      end

      daily_forecasts
    end

    def format_daily_forecasts(daily_forecasts)
      daily_forecasts.map do |date, data|
        {
          date: data[:date],
          high: data[:temps].max.round,
          low: data[:temps].min.round,
          description: data[:descriptions].first&.titleize
        }
      end.first(5) # Return 5-day forecast
    end
  end
end
