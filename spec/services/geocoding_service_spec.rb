require 'rails_helper'

RSpec.describe GeocodingService do
  describe '.locate' do
    context 'when the address resolves successfully' do
      before do
        Geocoder::Lookup::Test.add_stub('New York, NY', [
          {
            coordinates:  [40.7128, -74.0060],
            address:      'New York, NY, USA',
            city:         'New York',
            state:        'New York',
            country:      'United States',
            postal_code:  '10007'
          }
        ])
      end

      it 'returns a Result with the correct coordinates' do
        result = described_class.locate('New York, NY')

        expect(result).to be_a(GeocodingService::Result)
        expect(result.lat).to be_within(0.001).of(40.7128)
        expect(result.lon).to be_within(0.001).of(-74.0060)
      end

      it 'returns the postal code from the geocoder response' do
        result = described_class.locate('New York, NY')
        expect(result.postal_code).to eq('10007')
      end

      it 'returns city and country' do
        result = described_class.locate('New York, NY')
        expect(result.city).to eq('New York')
        expect(result.country).to eq('United States')
      end
    end

    context 'when no results are found' do
      before { Geocoder::Lookup::Test.add_stub('zzz-not-real', []) }

      it 'raises NotFoundError' do
        expect { described_class.locate('zzz-not-real') }
          .to raise_error(GeocodingService::NotFoundError)
      end
    end

    context 'when the geocoder result has no postal code' do
      before do
        Geocoder::Lookup::Test.add_stub('rural area', [
          {
            coordinates:  [51.5074, -0.1278],
            address:      'Some Rural Area',
            city:         'London',
            state:        'England',
            country:      'United Kingdom',
            postal_code:  nil
          }
        ])
      end

      it 'falls back to a rounded lat/lon string as the postal code' do
        result = described_class.locate('rural area')
        expect(result.postal_code).to match(/\d+\.\d+,/)
      end
    end

    context 'when city is blank' do
      before do
        Geocoder::Lookup::Test.add_stub('california', [
          {
            coordinates:  [36.7783, -119.4179],
            address:      'California, USA',
            city:         '',
            state:        'California',
            country:      'United States',
            postal_code:  '93701'
          }
        ])
      end

      it 'uses state as the city fallback' do
        result = described_class.locate('california')
        expect(result.city).to eq('California')
      end
    end
  end
end
