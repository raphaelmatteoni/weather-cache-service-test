Geocoder.configure(
  timeout: 5,
  # Nominatim (OpenStreetMap) requires a descriptive User-Agent header.
  # Without it the API returns an HTML error page instead of JSON.
  # https://operations.osmfoundation.org/policies/nominatim/
  http_headers: {
    "User-Agent" => "WeatherCacheService/1.0 (https://github.com/weather-cache-service)"
  }
)
