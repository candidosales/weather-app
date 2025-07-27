# Weather App Architecture Documentation

## Overview

The Weather App follows a layered architecture pattern with clear separation of concerns. This document outlines the object decomposition, responsibilities, and relationships between different components.

## Architecture Layers

### 1. Presentation Layer (Controllers & Views)
**Purpose**: Handle HTTP requests, user interactions, and render responses

#### Components:
- `WeatherController`: Main controller handling weather search requests
- Views: ERB templates for rendering weather data

#### Responsibilities:
- Accept user input (address/zip code)
- Validate request parameters
- Coordinate with business logic layer
- Handle user feedback (flash messages)
- Render appropriate views

#### Data Flow:
```
User Input → Controller → Orchestrator → Service → External API → Response
```

### 2. Business Logic Layer (Orchestrator)
**Purpose**: Coordinate between presentation and data layers

#### Components:
- `WeatherOrchestrator`: Main orchestrator for weather operations

#### Responsibilities:
- Validate input parameters
- Coordinate between model and service layers
- Handle business logic flow
- Manage error states
- Return structured responses

#### Relationships:
- **Depends on**: `Weather` model, `WeatherService`
- **Used by**: `WeatherController`

### 3. Domain Model Layer (Models)
**Purpose**: Represent business entities and enforce business rules

#### Components:
- `Weather`: Core domain model for weather data

#### Responsibilities:
- Validate input data (address/zip code requirements)
- Handle geocoding operations
- Process and format weather data
- Provide data access methods
- Maintain data integrity

#### Relationships:
- **Depends on**: `Geocoder` gem
- **Used by**: `WeatherOrchestrator`, `WeatherController`

### 4. Service Layer (External Integrations)
**Purpose**: Handle external API interactions and data processing

#### Components:
- `WeatherService`: Service for OpenWeather API integration

#### Responsibilities:
- Make HTTP requests to external APIs
- Handle API authentication
- Process API responses
- Implement caching strategies
- Manage error handling for external services

#### Relationships:
- **Depends on**: `HTTParty`, `Rails.cache`
- **Used by**: `WeatherOrchestrator`

## Object Decomposition Details

### Weather Model

#### Primary Responsibilities:
1. **Data Validation**: Ensure either address or zip code is provided
2. **Geocoding**: Convert addresses to coordinates
3. **Data Processing**: Format weather data for display
4. **Error Handling**: Manage geocoding and data errors

#### Key Methods:
- `initialize(attributes)`: Set up model with geocoding
- `current_temperature`: Extract current temperature from API data
- `high_low_temperature`: Extract high/low temperatures
- `weather_description`: Extract weather description
- `location_name`: Determine display name for location
- `extended_forecast`: Process 5-day forecast data
- `from_cache?`: Check if data came from cache
- `has_error?`: Check for any errors in data
- `error_message`: Get user-friendly error message

#### Data Flow:
```
Input → Validation → Geocoding → Coordinate Storage → Data Processing → Output
```

### WeatherOrchestrator

#### Primary Responsibilities:
1. **Request Coordination**: Manage the complete weather request flow
2. **Error Management**: Handle errors from all layers
3. **Data Flow Control**: Coordinate between model and service
4. **Response Formatting**: Structure responses for controller

#### Key Methods:
- `initialize(weather_params)`: Set up orchestrator with parameters
- `call`: Main orchestration method
- `fetch_forecast_data`: Coordinate data fetching

#### Data Flow:
```
Params → Model Validation → Geocoding Check → Service Call → Data Assignment → Response
```

### WeatherService

#### Primary Responsibilities:
1. **API Communication**: Handle all OpenWeather API interactions
2. **Caching Management**: Implement intelligent caching strategies
3. **Error Handling**: Manage API errors and network issues
4. **Data Transformation**: Process raw API responses

#### Key Methods:
- `get_current_weather(lat, lon)`: Fetch current weather data
- `get_forecast(lat, lon)`: Fetch 5-day forecast data
- `get_weather_by_zip(zip_code)`: Handle zip code requests
- `make_api_request(endpoint, **params)`: Make HTTP requests
- `handle_response(response)`: Process API responses

#### Data Flow:
```
Coordinates/Zip → Validation → Cache Check → API Request → Response Processing → Cached Result
```

### WeatherController

#### Primary Responsibilities:
1. **Request Handling**: Process HTTP requests
2. **Parameter Management**: Validate and sanitize input
3. **Response Coordination**: Manage view rendering
4. **User Feedback**: Handle flash messages

#### Key Methods:
- `index`: Display search form
- `create`: Process weather search requests
- `weather_params`: Sanitize input parameters

#### Data Flow:
```
HTTP Request → Parameter Validation → Orchestrator Call → Response Handling → View Rendering
```

## Data Flow Between Objects

### Complete Request Flow:
```
1. User submits form → WeatherController#create
2. Controller validates params → weather_params
3. Controller creates WeatherOrchestrator → new(weather_params)
4. Orchestrator validates Weather model → weather.valid?
5. Orchestrator checks geocoding → weather.geocoding_error
6. Orchestrator calls WeatherService → get_current_weather/get_forecast
7. Service checks cache → Rails.cache.fetch
8. Service makes API request → HTTParty.get
9. Service processes response → handle_response
10. Service caches result → Rails.cache.write
11. Orchestrator assigns data → weather.instance_variable_set
12. Controller receives result → orchestrator.call
13. Controller renders view → render :show
```

### Error Flow:
```
1. Invalid input → Weather validation fails
2. Geocoding fails → Weather.geocoding_error set
3. API fails → WeatherService raises ApiError
4. Network fails → WeatherService raises network error
5. Orchestrator catches errors → returns error hash
6. Controller handles errors → flash[:alert] + redirect
```

## Dependency Relationships

### Direct Dependencies:
- `WeatherController` → `WeatherOrchestrator`
- `WeatherOrchestrator` → `Weather`, `WeatherService`
- `Weather` → `Geocoder`
- `WeatherService` → `HTTParty`, `Rails.cache`

### External Dependencies:
- `OpenWeather API`: Weather data source
- `Nominatim API`: Geocoding service
- `Rails.cache`: Caching layer

## Service Boundaries

### WeatherController Boundary:
- **Input**: HTTP requests with weather parameters
- **Output**: Rendered views with weather data or error messages
- **Responsibilities**: Request/response handling only

### WeatherOrchestrator Boundary:
- **Input**: Validated weather parameters
- **Output**: Structured result with weather data or errors
- **Responsibilities**: Business logic coordination

### Weather Model Boundary:
- **Input**: Address/zip code and weather data
- **Output**: Formatted weather information
- **Responsibilities**: Data validation and processing

### WeatherService Boundary:
- **Input**: Coordinates or zip codes
- **Output**: Raw weather data from APIs
- **Responsibilities**: External API communication

## Data Transformation Flow

### Input Transformation:
```
User Input (String) → Validation → Geocoding → Coordinates (Float)
```

### API Data Transformation:
```
Raw API JSON → Parsed Hash → Formatted Data → Cached Result
```

### Output Transformation:
```
Processed Data → View Models → Rendered HTML
```

## Error Handling Strategy

### Validation Errors:
- **Layer**: Model validation
- **Handling**: Return validation error messages
- **User Impact**: Form validation feedback

### Geocoding Errors:
- **Layer**: Weather model
- **Handling**: Set geocoding_error attribute
- **User Impact**: Location not found message

### API Errors:
- **Layer**: WeatherService
- **Handling**: Raise custom exceptions
- **User Impact**: Service unavailable message

### Network Errors:
- **Layer**: WeatherService
- **Handling**: Rescue and log errors
- **User Impact**: Generic error message

## Caching Strategy

### Cache Keys:
- Current weather: `weather_current_{lat}_{lon}`
- Forecast: `weather_forecast_{lat}_{lon}`
- Zip code: `weather_zip_{zip_code}`

### Cache Expiration:
- Weather data: 30 minutes
- Geocoding: 1 day

### Cache Flow:
```
Request → Cache Check → Cache Hit/Miss → API Call → Cache Store → Response
```

## Scalability Considerations

### Current Limitations:
- Single-threaded request handling
- No background job processing
- SQLite database (not production-ready)
- No rate limiting protection

### Future Improvements:
- Background job processing for API calls
- Redis caching for better performance
- PostgreSQL for production database
- API rate limiting and circuit breakers
- Horizontal scaling with load balancers

## Security Considerations

### Input Validation:
- Parameter sanitization in controller
- Coordinate validation in service
- Zip code format validation

### API Security:
- API key management through credentials
- HTTPS for all external requests
- User-Agent headers for API requests

### Data Protection:
- No sensitive data logging
- Secure credential storage
- Input sanitization before processing 