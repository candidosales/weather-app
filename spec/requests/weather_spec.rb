require 'rails_helper'

RSpec.describe 'Weather Requests', type: :request do
  # Shared stubs for HTTP requests
  before do
    # Stub Nominatim geocoding requests for addresses
    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(
        query: hash_including({
          'accept-language' => 'en',
          'addressdetails' => '1',
          'format' => 'json'
        })
      )
      .to_return(
        status: 200,
        body: [
          {
            "lat" => "40.7128",
            "lon" => "-74.0060",
            "display_name" => "New York, NY, USA"
          }
        ].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Stub Nominatim geocoding requests for zip codes
    stub_request(:get, /https:\/\/nominatim\.openstreetmap\.org\/search/)
      .with(
        query: hash_including({
          'accept-language' => 'en',
          'addressdetails' => '1',
          'format' => 'json',
          'q' => '10001'
        })
      )
      .to_return(
        status: 200,
        body: [
          {
            "lat" => "40.7505",
            "lon" => "-73.9934",
            "display_name" => "10001, New York, NY, USA",
            "address" => {
              "city" => "New York",
              "state" => "NY",
              "country" => "USA"
            }
          }
        ].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Stub OpenWeatherMap current weather requests
    stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
      .with(
        query: hash_including({
          'appid' => anything,
          'units' => 'metric'
        })
      )
      .to_return(
        status: 200,
        body: {
          "main" => { "temp" => 22.0, "temp_max" => 25.0, "temp_min" => 18.0 },
          "weather" => [ { "description" => "clear sky" } ],
          "name" => "New York"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Stub OpenWeatherMap forecast requests
    stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
      .with(
        query: hash_including({
          'appid' => anything,
          'units' => 'metric'
        })
      )
      .to_return(
        status: 200,
        body: {
          "list" => [
            {
              "dt_txt" => "2025-07-26 12:00:00",
              "main" => { "temp" => 23.0 },
              "weather" => [ { "description" => "sunny" } ]
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe 'GET /' do
    it 'returns http success' do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the index template' do
      get root_path
      expect(response).to render_template(:index)
    end

    it 'contains weather form elements' do
      get root_path
      expect(response.body).to include('weather-form')
    end
  end

  describe 'POST /weather' do
    let(:valid_attributes) { { address: '123 Main St, New York, NY' } }
    let(:zip_code_attributes) { { zip_code: '10001' } }
    let(:invalid_attributes) { { address: '', zip_code: '' } }

    context 'with valid address parameters' do
      it 'renders the show template' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).to render_template(:show)
      end

      it 'returns http success' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).to have_http_status(:success)
      end

      it 'does not redirect' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).not_to be_redirect
      end

      it 'contains weather information in response' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response.body).to include('New York')
      end
    end

    context 'with valid zip code parameters' do
      it 'renders the show template' do
        post weather_index_path, params: { weather: zip_code_attributes }
        expect(response).to render_template(:show)
      end

      it 'returns http success' do
        post weather_index_path, params: { weather: zip_code_attributes }
        expect(response).to have_http_status(:success)
      end
    end

    context 'with cached weather data' do
      before do
        # Simulate cached data by making a request first, then making another
        post weather_index_path, params: { weather: valid_attributes }
      end

      it 'renders the show template' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).to render_template(:show)
      end

      it 'indicates data was retrieved from cache' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response.body).to include('retrieved from cache')
      end
    end

    context 'with invalid parameters' do
      it 'redirects to root path' do
        post weather_index_path, params: { weather: invalid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it 'sets a flash alert message' do
        post weather_index_path, params: { weather: invalid_attributes }
        follow_redirect!
        expect(response.body).to include("Address can&#39;t be blank, Zip code can&#39;t be blank")
      end
    end

    context 'when Weather object has errors' do
      before do
        # Stub geocoding to return empty results (no location found)
        stub_request(:get, "https://nominatim.openstreetmap.org/search")
          .with(
            query: hash_including({
              'accept-language' => 'en',
              'addressdetails' => '1',
              'format' => 'json',
              'q' => '123 Main St, New York, NY'
            })
          )
          .to_return(
            status: 200,
            body: [].to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects to root path' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it 'sets a flash alert with the error message' do
        post weather_index_path, params: { weather: valid_attributes }
        follow_redirect!
        expect(response.body).to include("Unable to find location")
      end
    end

    context 'when geocoding fails' do
      before do
        # Stub geocoding to return empty results for the specific invalid address
        stub_request(:get, "https://nominatim.openstreetmap.org/search")
          .with(
            query: hash_including({
              'accept-language' => 'en',
              'addressdetails' => '1',
              'format' => 'json',
              'q' => 'Invalid Address'
            })
          )
          .to_return(
            status: 200,
            body: [].to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects to root path with geocoding error' do
        post weather_index_path, params: { weather: { address: 'Invalid Address' } }
        expect(response).to redirect_to(root_path)
      end

      it 'sets appropriate error message' do
        post weather_index_path, params: { weather: { address: 'Invalid Address' } }
        follow_redirect!
        expect(response.body).to include("Unable to find location")
      end
    end

    context 'when API service fails' do
      before do
        # Stub OpenWeatherMap API to return error
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(
            query: hash_including({
              'appid' => anything,
              'units' => 'metric'
            })
          )
          .to_return(status: 500, body: "Internal Server Error")
      end

      it 'handles service errors gracefully' do
        post weather_index_path, params: { weather: valid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it 'displays appropriate error message' do
        post weather_index_path, params: { weather: valid_attributes }
        follow_redirect!
        expect(response.body).to include("Weather service")
      end
    end
  end

  describe 'parameter filtering' do
    context 'when unauthorized parameters are sent' do
      let(:params_with_extra) do
        {
          weather: {
            address: '123 Main St',
            zip_code: '10001',
            unauthorized_param: 'should_be_filtered',
            malicious_data: 'hacker_attempt'
          }
        }
      end

      before do
        # Global stubs are sufficient for this test
      end

      it 'filters out unauthorized parameters' do
        expect_any_instance_of(WeatherController).to receive(:weather_params).at_least(:once).and_call_original
        post weather_index_path, params: params_with_extra
        expect(response).to render_template(:show)
      end
    end
  end

  describe 'integration scenarios' do
    context 'complete weather request flow with realistic data' do
      it 'handles a successful weather request from start to finish' do
        post weather_index_path, params: { weather: { address: 'New York, NY' } }

        expect(response).to render_template(:show)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New York')
        expect(response.body).to include('Clear Sky')
      end

      it 'handles zip code requests' do
        post weather_index_path, params: { weather: { zip_code: '10001' } }

        expect(response).to render_template(:show)
        expect(response).to have_http_status(:success)
      end
    end

    context 'error handling flow' do
      it 'gracefully handles network timeouts' do
        # Stub API to timeout
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(
            query: hash_including({
              'appid' => anything,
              'units' => 'metric'
            })
          )
          .to_timeout

        post weather_index_path, params: { weather: { address: 'New York, NY' } }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Weather service")
      end
    end
  end
end
