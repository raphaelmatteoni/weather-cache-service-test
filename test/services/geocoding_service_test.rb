require "test_helper"

class GeocodingServiceTest < ActiveSupport::TestCase
  # Geocoder::Lookup::Test.add_stub registers a fake result for a given query.
  # This avoids any real network calls to Nominatim.

  test "returns a Result with coordinates and postal code for a valid address" do
    Geocoder::Lookup::Test.add_stub("New York, NY", [
      {
        coordinates:  [ 40.7128, -74.0060 ],
        address:      "New York, NY, USA",
        city:         "New York",
        state:        "New York",
        country:      "United States",
        postal_code:  "10007"
      }
    ])

    result = GeocodingService.locate("New York, NY")

    assert_instance_of GeocodingService::Result, result
    assert_in_delta 40.7128, result.lat, 0.001
    assert_in_delta(-74.0060, result.lon, 0.001)
    assert_equal "10007", result.postal_code
    assert_equal "New York", result.city
    assert_equal "United States", result.country
  end

  test "raises NotFoundError when Geocoder returns no results" do
    Geocoder::Lookup::Test.add_stub("zzz-not-real", [])

    assert_raises(GeocodingService::NotFoundError) do
      GeocodingService.locate("zzz-not-real")
    end
  end

  test "falls back to coordinate-based key when postal code is absent" do
    Geocoder::Lookup::Test.add_stub("rural area", [
      {
        coordinates:  [ 51.5074, -0.1278 ],
        address:      "Some Rural Area",
        city:         "London",
        state:        "England",
        country:      "United Kingdom",
        postal_code:  nil
      }
    ])

    result = GeocodingService.locate("rural area")
    # Should produce something like "51.51,-0.13"
    assert_match(/\d+\.\d+,/, result.postal_code)
  end

  test "uses state as city fallback when city is blank" do
    Geocoder::Lookup::Test.add_stub("california", [
      {
        coordinates:  [ 36.7783, -119.4179 ],
        address:      "California, USA",
        city:         "",
        state:        "California",
        country:      "United States",
        postal_code:  "93701"
      }
    ])

    result = GeocodingService.locate("california")
    assert_equal "California", result.city
  end
end
