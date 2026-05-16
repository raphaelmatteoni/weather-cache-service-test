require "test_helper"

class GeocodingServiceTest < ActiveSupport::TestCase
  # Stub Geocoder to avoid real network calls in tests
  setup do
    @fake_result = Minitest::Mock.new
    @fake_result.expect(:coordinates, [ 40.7128, -74.0060 ])
    @fake_result.expect(:coordinates, [ 40.7128, -74.0060 ])
    @fake_result.expect(:latitude, 40.7128)
    @fake_result.expect(:longitude, -74.0060)
    @fake_result.expect(:postal_code, "10007")
    @fake_result.expect(:city, "New York")
    @fake_result.expect(:state, "New York")
    @fake_result.expect(:country, "United States")
  end

  test "returns a Result with coordinates and postal code for a valid address" do
    Geocoder.stub(:search, [ @fake_result ]) do
      result = GeocodingService.locate("New York, NY")

      assert_instance_of GeocodingService::Result, result
      assert_in_delta 40.7128, result.lat, 0.001
      assert_in_delta(-74.0060, result.lon, 0.001)
      assert_equal "10007", result.postal_code
      assert_equal "New York", result.city
    end
  end

  test "raises NotFoundError when Geocoder returns no results" do
    Geocoder.stub(:search, []) do
      assert_raises(GeocodingService::NotFoundError) do
        GeocodingService.locate("zzz-not-a-real-place-xyz")
      end
    end
  end

  test "falls back to coordinate-based key when postal code is missing" do
    result_without_zip = Minitest::Mock.new
    result_without_zip.expect(:coordinates, [ 51.5074, -0.1278 ])
    result_without_zip.expect(:coordinates, [ 51.5074, -0.1278 ])
    result_without_zip.expect(:latitude, 51.5074)
    result_without_zip.expect(:longitude, -0.1278)
    result_without_zip.expect(:postal_code, nil)
    result_without_zip.expect(:city, "London")
    result_without_zip.expect(:state, "England")
    result_without_zip.expect(:country, "United Kingdom")

    Geocoder.stub(:search, [ result_without_zip ]) do
      result = GeocodingService.locate("London")
      assert_match(/\d+\.\d+,/, result.postal_code)
    end
  end
end
