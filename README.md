# Weather App

A modern Rails 8 weather application that provides current weather conditions and 5-day forecasts for any location. Built with Ruby on Rails and integrates with OpenWeather API for real-time weather data.

## Features

- 🌤️ **Current Weather**: Get real-time temperature, conditions, and high/low temperatures
- 📅 **5-Day Forecast**: Extended weather predictions with daily highs and lows
- 🔍 **Location Search**: Search by address or ZIP code with automatic geocoding
- ⚡ **Caching**: Intelligent caching for improved performance
- 🐳 **Docker Support**: Containerized deployment ready
- 🧪 **CI/CD**: GitHub Actions for automated testing and deployment

## Tech Stack

- **Ruby 3.4.1** with Rails 8.0.2
- **HTTParty** for API requests
- **Geocoder** for address-to-coordinates conversion
- **RSpec** for testing
- **Docker** for containerization

## Prerequisites

- Ruby 3.4.1
- Rails 8.0.2
- OpenWeather API key

## Setup

### 1. Clone the repository
```bash
git clone <repository-url>
cd weather-app
```

### 2. Install dependencies
```bash
bundle install
```

### 3. Configure OpenWeather API

Get your free API key from [OpenWeather](https://openweathermap.org/api) and set it as an environment variable:

```bash
export OPENWEATHER_API_KEY=your_api_key_here
```

Or add it to your Rails credentials:
```bash
bin/rails credentials:edit
```

⚠️ For this tests, you can use the following API key: `69da177b54fe5e50092d0e81b2df6dc3`. This key will be deleted after 1 week.

Add:
```yaml
openweather_api_key: your_api_key_here
```

### 4. Start the server
```bash
bin/rails server
```

Visit `http://localhost:3000` to use the application.

## Docker Commands

### Build the Docker image
```bash
docker build -t weather-app .
```

### Run with Docker (Development)
```bash
docker run -d -p 3000:80 -e RAILS_ENV=development -e OPENWEATHER_API_KEY=69da177b54fe5e50092d0e81b2df6dc3 weather-app
```

### Run with Docker (Production)
```bash
docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY=your_master_key_here \
  -e OPENWEATHER_API_KEY=your_api_key_here \
  --name weather-app-prod \
  weather-app
```

### Docker Compose (Alternative)
Create a `docker-compose.yml` file:
```yaml
version: '3.8'
services:
  weather-app:
    build: .
    ports:
      - "3000:80"
    environment:
      - RAILS_ENV=production
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
      - OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
    volumes:
      - ./storage:/rails/storage
```

Then run:
```bash
docker-compose up -d
```

### Useful Docker commands
```bash
# View logs
docker logs weather-app

# Stop container
docker stop weather-app

# Remove container
docker rm weather-app

# Execute commands in running container
docker exec -it weather-app bin/rails console
```

## Testing

Run the test suite:
```bash
bundle exec rspec
```

Run specific test files:
```bash
bundle exec rspec spec/controllers/weather_controller_spec.rb
bundle exec rspec spec/services/weather_service_spec.rb
```

## Development

### Code Quality
```bash
# Run RuboCop for code style checking
bundle exec rubocop

# Run Brakeman for security analysis
bundle exec brakeman
```

## API Endpoints

- `GET /` - Home page with weather search form
- `POST /weather` - Submit weather search (address or ZIP code)
- `GET /up` - Health check endpoint

## Environment Variables

- `OPENWEATHER_API_KEY` - Your OpenWeather API key
- `RAILS_MASTER_KEY` - Rails master key for production (Docker)
- `RAILS_ENV` - Rails environment (development/production)
