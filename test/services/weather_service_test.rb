require "test_helper"

class WeatherServiceTest < ActiveSupport::TestCase
  OPEN_METEO_BODY = {
    "current" => {
      "temperature_2m"       => 22.4,
      "apparent_temperature" => 21.0,
      "weathercode"          => 1,
      "windspeed_10m"        => 15.3,
      "relativehumidity_2m"  => 60
    },
    "daily" => {
      "time"               => [ "2026-05-16", "2026-05-17", "2026-05-18",
                                "2026-05-19", "2026-05-20", "2026-05-21", "2026-05-22" ],
      "temperature_2m_max" => [ 24.0, 25.5, 23.0, 20.0, 19.5, 22.0, 26.0 ],
      "temperature_2m_min" => [ 15.0, 16.5, 14.0, 12.0, 11.5, 13.0, 17.0 ],
      "weathercode"        => [ 1, 3, 61, 80, 0, 1, 2 ],
      "precipitation_sum"  => [ 0.0, 0.0, 3.5, 8.2, 0.0, 0.0, 0.0 ]
    }
  }.to_json.freeze

  setup do
    Geocoder::Lookup::Test.add_stub("New York, NY", [
      {
        coordinates: [ 40.7128, -74.0060 ],
        city: "New York", state: "New York",
        country: "United States", postal_code: "10007"
      }
    ])

    stub_request(:get, /api.open-meteo.com/)
      .to_return(status: 200, body: OPEN_METEO_BODY, headers: { "Content-Type" => "application/json" })

    Rails.cache.clear
  end

  teardown { Rails.cache.clear }

  test "returns forecast data on first call with cached: false" do
    result = WeatherService.call("New York, NY")

    assert_not result[:cached], "First call should not be from cache"
    assert_equal 22.4, result[:data][:current_temp]
    assert_equal "Mainly clear", result[:data][:condition]
    assert_equal "10007", result[:location].postal_code
  end

  test "returns cached: true on second call for the same postal code" do
    WeatherService.call("New York, NY")
    result = WeatherService.call("New York, NY")

    assert result[:cached], "Second call should be served from cache"
    # Only one real HTTP request should have been made
    assert_requested(:get, /api.open-meteo.com/, times: 1)
  end

  test "daily_forecast contains 7 entries" do
    result = WeatherService.call("New York, NY")
    assert_equal 7, result[:data][:daily_forecast].size
  end

  test "each daily entry has the expected keys" do
    result = WeatherService.call("New York, NY")
    day = result[:data][:daily_forecast].first

    assert_equal %i[date temp_max temp_min condition precipitation], day.keys
  end

  test "raises FetchError when Open-Meteo returns a non-200 status" do
    stub_request(:get, /api.open-meteo.com/).to_return(status: 503, body: "Service Unavailable")

    assert_raises(WeatherService::FetchError) do
      WeatherService.call("New York, NY")
    end
  end

  test "raises FetchError on network timeout" do
    stub_request(:get, /api.open-meteo.com/).to_timeout

    assert_raises(WeatherService::FetchError) do
      WeatherService.call("New York, NY")
    end
  end
end
