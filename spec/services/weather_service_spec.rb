require 'rails_helper'

RSpec.describe WeatherService do
  let(:open_meteo_body) do
    {
      'current' => {
        'temperature_2m'       => 22.4,
        'apparent_temperature' => 21.0,
        'weathercode'          => 1,
        'windspeed_10m'        => 15.3,
        'relativehumidity_2m'  => 60
      },
      'daily' => {
        'time'               => %w[2026-05-16 2026-05-17 2026-05-18 2026-05-19 2026-05-20 2026-05-21 2026-05-22],
        'temperature_2m_max' => [ 24.0, 25.5, 23.0, 20.0, 19.5, 22.0, 26.0 ],
        'temperature_2m_min' => [ 15.0, 16.5, 14.0, 12.0, 11.5, 13.0, 17.0 ],
        'weathercode'        => [ 1, 3, 61, 80, 0, 1, 2 ],
        'precipitation_sum'  => [ 0.0, 0.0, 3.5, 8.2, 0.0, 0.0, 0.0 ]
      }
    }.to_json
  end

  before do
    Geocoder::Lookup::Test.add_stub('New York, NY', [
      {
        coordinates: [ 40.7128, -74.0060 ],
        city: 'New York', state: 'New York',
        country: 'United States', postal_code: '10007'
      }
    ])

    stub_request(:get, /api.open-meteo.com/)
      .to_return(status: 200, body: open_meteo_body, headers: { 'Content-Type' => 'application/json' })
  end

  describe '.call' do
    context 'on the first request for a postal code' do
      it 'returns cached: false' do
        result = described_class.call('New York, NY')
        expect(result[:cached]).to be false
      end

      it 'returns the current temperature from the API' do
        result = described_class.call('New York, NY')
        expect(result[:data][:current_temp]).to eq(22.4)
      end

      it 'maps the WMO weather code to a human-readable condition' do
        result = described_class.call('New York, NY')
        expect(result[:data][:condition]).to eq('Mainly clear')
      end

      it 'includes the resolved location' do
        result = described_class.call('New York, NY')
        expect(result[:location].postal_code).to eq('10007')
      end
    end

    context 'on a subsequent request for the same postal code' do
      it 'returns cached: true' do
        described_class.call('New York, NY')
        result = described_class.call('New York, NY')
        expect(result[:cached]).to be true
      end

      it 'does not call the Open-Meteo API a second time' do
        described_class.call('New York, NY')
        described_class.call('New York, NY')
        expect(a_request(:get, /api.open-meteo.com/)).to have_been_made.once
      end
    end

    context 'with a 7-day daily forecast' do
      subject(:daily) { described_class.call('New York, NY')[:data][:daily_forecast] }

      it 'contains 7 entries' do
        expect(daily.size).to eq(7)
      end

      it 'each entry has the expected keys' do
        expect(daily.first.keys).to eq(%i[date temp_max temp_min condition precipitation])
      end
    end

    context 'when the Open-Meteo API returns an error' do
      before { stub_request(:get, /api.open-meteo.com/).to_return(status: 503, body: 'down') }

      it 'raises FetchError' do
        expect { described_class.call('New York, NY') }
          .to raise_error(WeatherService::FetchError)
      end
    end

    context 'when the network times out' do
      before { stub_request(:get, /api.open-meteo.com/).to_timeout }

      it 'raises FetchError' do
        expect { described_class.call('New York, NY') }
          .to raise_error(WeatherService::FetchError)
      end
    end
  end
end
