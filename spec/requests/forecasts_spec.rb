require 'rails_helper'

RSpec.describe 'Forecasts', type: :request do
  let(:open_meteo_body) do
    {
      'current' => {
        'temperature_2m'       => 18.5,
        'apparent_temperature' => 17.0,
        'weathercode'          => 2,
        'windspeed_10m'        => 10.0,
        'relativehumidity_2m'  => 65
      },
      'daily' => {
        'time'               => [ '2026-05-16' ],
        'temperature_2m_max' => [ 20.0 ],
        'temperature_2m_min' => [ 14.0 ],
        'weathercode'        => [ 2 ],
        'precipitation_sum'  => [ 0.0 ]
      }
    }.to_json
  end

  before do
    Geocoder::Lookup::Test.add_stub('London', [
      {
        coordinates: [ 51.5074, -0.1278 ],
        city: 'London', state: 'England',
        country: 'United Kingdom', postal_code: 'EC1A1BB'
      }
    ])
    Geocoder::Lookup::Test.add_stub('zzz-not-real', [])

    stub_request(:get, /api.open-meteo.com/)
      .to_return(status: 200, body: open_meteo_body, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'GET /' do
    context 'with no address param' do
      it 'renders the search form' do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<form')
      end

      it 'does not show a forecast card' do
        get root_path
        expect(response.body).not_to include('forecast-card')
      end
    end

    context 'with a valid address' do
      it 'returns HTTP 200' do
        get root_path, params: { address: 'London' }
        expect(response).to have_http_status(:ok)
      end

      it 'renders the forecast card' do
        get root_path, params: { address: 'London' }
        expect(response.body).to include('forecast-card')
      end

      it 'shows the live badge on the first request' do
        get root_path, params: { address: 'London' }
        expect(response.body).to include('cache-badge miss')
      end

      it 'shows the cached badge on subsequent requests for the same postal code' do
        get root_path, params: { address: 'London' }
        get root_path, params: { address: 'London' }
        expect(response.body).to include('cache-badge hit')
      end
    end

    context 'when the address cannot be geocoded' do
      it 'shows an alert instead of crashing' do
        get root_path, params: { address: 'zzz-not-real' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('alert-danger')
      end
    end

    context 'when the weather API is unavailable' do
      before { stub_request(:get, /api.open-meteo.com/).to_return(status: 503, body: 'down') }

      it 'shows an alert instead of crashing' do
        get root_path, params: { address: 'London' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('alert-danger')
      end
    end
  end
end
