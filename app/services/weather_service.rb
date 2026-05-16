require "net/http"
require "json"

# Orchestrates geocoding, caching, and weather fetching.
# Entry point: WeatherService.call(address, unit: :celsius) → { data:, cached:, location:, unit: }
class WeatherService
  class FetchError < StandardError; end

  CACHE_TTL  = 30.minutes
  VALID_UNITS = %w[celsius fahrenheit].freeze

  # WMO Weather Interpretation Codes → human-readable description
  # https://open-meteo.com/en/docs#weathervariables
  WEATHER_CODES = {
    0 => "Clear sky",
    1 => "Mainly clear", 2 => "Partly cloudy", 3 => "Overcast",
    45 => "Fog", 48 => "Depositing rime fog",
    51 => "Light drizzle", 53 => "Moderate drizzle", 55 => "Dense drizzle",
    61 => "Slight rain", 63 => "Moderate rain", 65 => "Heavy rain",
    71 => "Slight snow", 73 => "Moderate snow", 75 => "Heavy snow",
    77 => "Snow grains",
    80 => "Slight showers", 81 => "Moderate showers", 82 => "Violent showers",
    85 => "Slight snow showers", 86 => "Heavy snow showers",
    95 => "Thunderstorm", 96 => "Thunderstorm with hail", 99 => "Thunderstorm with heavy hail"
  }.freeze

  def self.call(address, unit: "celsius")
    new(address, unit: unit).call
  end

  def initialize(address, unit: "celsius")
    @address = address
    @unit    = VALID_UNITS.include?(unit.to_s) ? unit.to_s : "celsius"
  end

  def call
    location  = GeocodingService.locate(@address)
    cache_key = "forecast/#{location.postal_code}/#{@unit}"

    # Check existence before fetch so we can report the cache hit accurately.
    # Rails.cache.fetch would populate the cache on a miss, so we snapshot
    # the state beforehand.
    from_cache = Rails.cache.exist?(cache_key)

    data = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_forecast(location)
    end

    { data: data, cached: from_cache, location: location, unit: @unit }
  end

  private

  def fetch_forecast(location)
    uri = build_uri(location)
    response = perform_request(uri)
    parse_response(response)
  end

  def build_uri(location)
    URI("https://api.open-meteo.com/v1/forecast").tap do |uri|
      uri.query = URI.encode_www_form(
        latitude:       location.lat,
        longitude:      location.lon,
        current:        "temperature_2m,apparent_temperature,weathercode,windspeed_10m,relativehumidity_2m",
        daily:          "temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum",
        temperature_unit: @unit,
        wind_speed_unit:  "kmh",
        timezone:       "auto",
        forecast_days:  7
      )
    end
  end

  def perform_request(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 5, open_timeout: 5) do |http|
      http.get(uri.request_uri)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise FetchError, "Weather API timed out: #{e.message}"
  rescue SocketError => e
    raise FetchError, "Could not reach weather API: #{e.message}"
  end

  def parse_response(response)
    raise FetchError, "Weather API returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    current = body.fetch("current")
    daily   = body.fetch("daily")

    {
      current_temp:      current["temperature_2m"],
      feels_like:        current["apparent_temperature"],
      humidity:          current["relativehumidity_2m"],
      wind_speed:        current["windspeed_10m"],
      condition:         WEATHER_CODES.fetch(current["weathercode"], "Unknown"),
      daily_forecast:    build_daily_forecast(daily),
      fetched_at:        Time.current
    }
  end

  def build_daily_forecast(daily)
    dates     = daily["time"]
    max_temps = daily["temperature_2m_max"]
    min_temps = daily["temperature_2m_min"]
    codes     = daily["weathercode"]
    precip    = daily["precipitation_sum"]

    dates.each_with_index.map do |date, i|
      {
        date:        Date.parse(date),
        temp_max:    max_temps[i],
        temp_min:    min_temps[i],
        condition:   WEATHER_CODES.fetch(codes[i], "Unknown"),
        precipitation: precip[i]
      }
    end
  end
end
