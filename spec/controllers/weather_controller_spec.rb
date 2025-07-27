require 'rails_helper'

RSpec.describe WeatherController, type: :controller do
  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end

    it 'assigns a new Weather object' do
      get :index
      expect(assigns(:weather)).to be_a(Weather)
      expect(assigns(:weather).address).to be_nil
      expect(assigns(:weather).zip_code).to be_nil
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) { { address: '123 Main St, New York, NY' } }
    let(:zip_code_attributes) { { zip_code: '10001' } }
    let(:invalid_attributes) { { address: '', zip_code: '' } }

    context 'with valid address parameters' do
      before do
        # Mock the orchestrator to return successful result
        forecast_data = {
          current: {
            "main" => { "temp" => 22.0, "temp_max" => 25.0, "temp_min" => 18.0 },
            "weather" => [ { "description" => "clear sky" } ],
            "name" => "New York"
          },
          forecast: {
            "list" => [
              {
                "dt_txt" => "2025-07-26 12:00:00",
                "main" => { "temp" => 23.0 },
                "weather" => [ { "description" => "sunny" } ]
              }
            ]
          },
          from_cache: false
        }

        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: false,
          from_cache?: false,
          forecast_data: forecast_data,
          address: '123 Main St, New York, NY'
        )

        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'creates a valid Weather object' do
        post :create, params: { weather: valid_attributes }
        expect(assigns(:weather)).to be_present
      end

      it 'renders the show template' do
        post :create, params: { weather: valid_attributes }
        expect(response).to render_template(:show)
      end

      it 'does not redirect' do
        post :create, params: { weather: valid_attributes }
        expect(response).not_to be_redirect
      end

      it 'does not set flash alert' do
        post :create, params: { weather: valid_attributes }
        expect(flash[:alert]).to be_nil
      end
    end

    context 'with valid zip code parameters' do
      before do
        forecast_data = {
          current: {
            "main" => { "temp" => 20.0, "temp_max" => 23.0, "temp_min" => 17.0 },
            "weather" => [ { "description" => "partly cloudy" } ],
            "name" => "New York"
          },
          coordinates: {
            city: "New York, NY"
          },
          from_cache: false
        }

        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: false,
          from_cache?: false,
          forecast_data: forecast_data,
          zip_code: '10001'
        )

        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'creates a valid Weather object with zip code' do
        post :create, params: { weather: zip_code_attributes }
        expect(assigns(:weather)).to be_present
      end

      it 'renders the show template' do
        post :create, params: { weather: zip_code_attributes }
        expect(response).to render_template(:show)
      end
    end

    context 'with cached weather data' do
      before do
        forecast_data = {
          current: {
            "main" => { "temp" => 22.0 },
            "weather" => [ { "description" => "clear sky" } ],
            "name" => "New York"
          },
          from_cache: true
        }

        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: false,
          from_cache?: true,
          forecast_data: forecast_data
        )

        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'sets a flash notice about cached data' do
        post :create, params: { weather: valid_attributes }
        expect(flash.now[:notice]).to eq("Weather data retrieved from cache.")
      end

      it 'renders the show template' do
        post :create, params: { weather: valid_attributes }
        expect(response).to render_template(:show)
      end
    end

    context 'with invalid parameters' do
      before do
        weather_instance = instance_double(Weather, valid?: false, errors: double(full_messages: [ "Address can't be blank" ]))
        orchestrator_result = { weather: weather_instance, error: "Address can't be blank" }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'redirects to root path' do
        post :create, params: { weather: invalid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it 'sets a flash alert message' do
        post :create, params: { weather: invalid_attributes }
        expect(flash[:alert]).to eq("Address can't be blank")
      end
    end

    context 'when Weather object has errors' do
      before do
        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: true,
          error_message: "Unable to find location"
        )
        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'redirects to root path' do
        post :create, params: { weather: valid_attributes }
        expect(response).to redirect_to(root_path)
      end

      it 'sets a flash alert with the error message' do
        post :create, params: { weather: valid_attributes }
        expect(flash[:alert]).to eq("Unable to find location")
      end
    end

    context 'when geocoding fails' do
      before do
        weather_instance = instance_double(Weather,
          valid?: true,
          geocoding_error: "Unable to find location for 'Invalid Address'. Please try a different address or zip code."
        )
        orchestrator_result = { weather: weather_instance, error: "Unable to find location for 'Invalid Address'. Please try a different address or zip code." }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'redirects to root path with geocoding error' do
        post :create, params: { weather: { address: 'Invalid Address' } }
        expect(response).to redirect_to(root_path)
      end

      it 'sets appropriate error message' do
        post :create, params: { weather: { address: 'Invalid Address' } }
        expect(flash[:alert]).to include("Unable to find location")
      end
    end

    context 'when API service fails' do
      before do
        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: true,
          error_message: "Weather service unavailable"
        )
        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )
      end

      it 'handles service errors gracefully' do
        post :create, params: { weather: valid_attributes }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Weather service unavailable")
      end
    end
  end

  describe 'private methods' do
    describe '#weather_params' do
      let(:controller) { described_class.new }
      let(:params) do
        ActionController::Parameters.new(
          weather: {
            address: '123 Main St',
            zip_code: '10001',
            unauthorized_param: 'should_be_filtered'
          }
        )
      end

      before do
        allow(controller).to receive(:params).and_return(params)
      end

      it 'permits only address and zip_code parameters' do
        permitted_params = controller.send(:weather_params)
        expect(permitted_params.keys).to contain_exactly('address', 'zip_code')
        expect(permitted_params['address']).to eq('123 Main St')
        expect(permitted_params['zip_code']).to eq('10001')
        expect(permitted_params).not_to have_key('unauthorized_param')
      end
    end
  end

  describe 'integration scenarios' do
    context 'complete weather request flow' do
      it 'handles a successful weather request from start to finish' do
        forecast_data = {
          current: {
            "main" => { "temp" => 22.0, "temp_max" => 25.0, "temp_min" => 18.0 },
            "weather" => [ { "description" => "clear sky" } ],
            "name" => "New York"
          },
          forecast: {
            "list" => []
          },
          from_cache: false
        }

        weather_instance = instance_double(Weather,
          valid?: true,
          has_error?: false,
          from_cache?: false,
          forecast_data: forecast_data,
          address: 'New York, NY'
        )

        orchestrator_result = { weather: weather_instance, error: nil }
        allow(WeatherOrchestrator).to receive(:new).and_return(
          instance_double(WeatherOrchestrator, call: orchestrator_result)
        )

        post :create, params: { weather: { address: 'New York, NY' } }

        expect(response).to render_template(:show)
        expect(flash[:alert]).to be_nil
      end
    end
  end
end
