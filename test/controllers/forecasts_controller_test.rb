require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  OPEN_METEO_BODY = {
    "current" => {
      "temperature_2m"       => 18.5,
      "apparent_temperature" => 17.0,
      "weathercode"          => 2,
      "windspeed_10m"        => 10.0,
      "relativehumidity_2m"  => 65
    },
    "daily" => {
      "time"               => [ "2026-05-16" ],
      "temperature_2m_max" => [ 20.0 ],
      "temperature_2m_min" => [ 14.0 ],
      "weathercode"        => [ 2 ],
      "precipitation_sum"  => [ 0.0 ]
    }
  }.to_json.freeze

  setup do
    Geocoder::Lookup::Test.add_stub("London", [
      {
        coordinates: [ 51.5074, -0.1278 ],
        city: "London", state: "England",
        country: "United Kingdom", postal_code: "EC1A1BB"
      }
    ])
    Geocoder::Lookup::Test.add_stub("zzz-not-real", [])

    stub_request(:get, /api.open-meteo.com/)
      .to_return(status: 200, body: OPEN_METEO_BODY, headers: { "Content-Type" => "application/json" })

    Rails.cache.clear
  end

  teardown { Rails.cache.clear }

  test "GET / renders search form" do
    get root_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='address']"
  end

  test "GET / without address does not show forecast card" do
    get root_path
    assert_response :success
    assert_select ".forecast-card", count: 0
  end

  test "GET / with valid address shows forecast card" do
    get root_path, params: { address: "London" }
    assert_response :success
    assert_select ".forecast-card"
  end

  test "GET / first request shows live badge" do
    get root_path, params: { address: "London" }
    assert_select ".cache-badge.miss"
  end

  test "GET / second request for same postal code shows cached badge" do
    get root_path, params: { address: "London" }
    get root_path, params: { address: "London" }
    assert_select ".cache-badge.hit"
  end

  test "GET / shows alert when address is not found" do
    get root_path, params: { address: "zzz-not-real" }
    assert_response :success
    assert_select ".alert-danger"
  end

  test "GET / shows alert when weather API is unavailable" do
    stub_request(:get, /api.open-meteo.com/).to_return(status: 503, body: "down")
    get root_path, params: { address: "London" }
    assert_response :success
    assert_select ".alert-danger"
  end
end
