class GeocodingService
  class NotFoundError < StandardError; end

  # Value object returned by .locate — immutable, pattern-matchable
  Result = Data.define(:lat, :lon, :postal_code, :city, :country)

  # Converts any address string (full address, city name, or postal code) into
  # a Result with coordinates and postal code. The postal code is used as the
  # cache key in WeatherService, so this normalisation step is critical.
  def self.locate(address)
    results = Geocoder.search(address.strip)
    raise NotFoundError, "Could not find location for: \"#{address}\"" if results.empty?

    # Prefer the first result that has coordinates — Nominatim sometimes returns
    # results without lat/lon for ambiguous queries.
    geo = results.find { |r| r.coordinates.any? } || results.first

    raise NotFoundError, "Could not resolve coordinates for: \"#{address}\"" if geo.coordinates.empty?

    Result.new(
      lat:         geo.latitude,
      lon:         geo.longitude,
      postal_code: geo.postal_code.presence || derive_postal_code(geo),
      city:        geo.city.presence || geo.state || geo.country,
      country:     geo.country
    )
  end

  private_class_method def self.derive_postal_code(geo)
    # Fallback: round coordinates to 2 decimal places and use as a stable key.
    # This handles locations where Nominatim returns no postal code (e.g., rural
    # areas or some international regions), ensuring caching still works.
    "#{geo.latitude.round(2)},#{geo.longitude.round(2)}"
  end
end
