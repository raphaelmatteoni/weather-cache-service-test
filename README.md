# Weather Cache Service

A Ruby on Rails application that accepts any address or postal code, retrieves a 7-day weather forecast, and caches the result for 30 minutes per postal code. A visible badge tells the user whether the data came from the cache or a live API call.

---

## Features

- Search by any address or postal code (international support)
- Current temperature, feels-like, humidity, and wind speed
- 7-day extended forecast with daily high/low temperatures and precipitation (bonus)
- Results cached for **30 minutes** keyed by postal code
- Clear **"Live" / "Cached"** indicator on every result

---

## Tech Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Rails 8 | Required by the brief |
| Geocoding | `geocoder` gem (Nominatim) | Free, no API key, works globally |
| Weather data | [Open-Meteo](https://open-meteo.com/) | Free, no API key, returns current + 7-day forecast |
| HTTP client | `Net::HTTP` (stdlib) | No extra dependency for a thin wrapper |
| Cache store | `Rails.cache` (`:memory_store` in dev) | Fits the 30-min TTL requirement with zero config; Solid Cache takes over in production |
| Test framework | `rspec-rails` | Expressive `describe/context/it` structure; preferred for senior-level readability |
| Test HTTP stubbing | `webmock` | Industry standard; prevents any real network calls during tests |
| Database | SQLite | Minimal setup for local running |

---

## Architecture

```
ForecastsController#index
  └── WeatherService.call(address)
        ├── GeocodingService.locate(address)     # address → lat/lon + postal_code
        │     └── Geocoder (Nominatim)
        ├── Rails.cache.exist?(cache_key)        # snapshot before fetch
        └── Rails.cache.fetch(cache_key, 30.min)
              └── (on miss) Open-Meteo API       # Net::HTTP GET
```

**Cache-aside pattern:** `Rails.cache.exist?` is called *before* `fetch` to record whether the result was already in cache. This is important because `fetch` populates the cache on a miss — checking existence after would always return `true`.

**Cache key:** `"forecast/#{postal_code}"` — the postal code is normalised from the geocoder result. For locations without a known postal code (some rural areas), a rounded lat/lon string is used as fallback.

**Service objects** (`app/services/`) keep all business logic out of the controller. Each service has a single responsibility, making them independently testable.

---

## Running Locally

### Option A — Docker (recommended, zero setup)

```bash
git clone https://github.com/raphaelmatteoni/weather-cache-service-test.git
cd weather-cache-service-test

docker compose up
```

Open [http://localhost:3000](http://localhost:3000) and type any address or postal code.

> The first build takes ~2 minutes while Docker downloads the Ruby image and installs gems. Subsequent starts are instant.

### Option B — Local Ruby

**Prerequisites:** Ruby 3.3.5 (see `.ruby-version`) + Bundler

```bash
git clone https://github.com/raphaelmatteoni/weather-cache-service-test.git
cd weather-cache-service-test

bundle install
bin/rails db:prepare
bin/rails server
```

Open [http://localhost:3000](http://localhost:3000) and type any address or postal code.

> **No API keys needed.** Both the geocoding provider (Nominatim/OpenStreetMap) and the weather API (Open-Meteo) are free and require no registration.

### Running tests

**With Docker:**
```bash
docker compose run --rm web bundle exec rspec
```

**Local Ruby:**
```bash
bundle exec rspec
```

24 examples, 0 failures. No network requests are made during the test suite — WebMock intercepts all HTTP calls and Geocoder is configured to use its built-in test lookup.

---

## Design Decisions & Trade-offs

### Why Open-Meteo instead of OpenWeatherMap?

Open-Meteo requires no API key. This means any reviewer can clone and run the project immediately without signing up for an account. It also provides all required data: current temperature, feels-like, humidity, wind, and a 7-day daily forecast with high/low and precipitation.

### Why `Net::HTTP` instead of Faraday?

The Open-Meteo call is a single, simple GET request. Adding Faraday would introduce a dependency for no practical benefit at this scale. `Net::HTTP` is part of Ruby's stdlib and is sufficient when wrapped properly with timeout configuration.

### Why `geocoder` + Nominatim?

Same zero-config reasoning as above. Nominatim covers addresses worldwide. The `geocoder` gem ships a test lookup (`Geocoder::Lookup::Test`) that lets tests control geocoding results without network calls.

### Why `Rails.cache.exist?` before `fetch`?

`Rails.cache.fetch` populates the cache on a miss and returns the block's result. Checking existence *after* the fetch would always report a hit. Snapshotting the state *before* the fetch gives an accurate `cached:` flag.

### Caching in development

Rails sets `config.cache_store = :memory_store` in development. `Rails.cache.fetch` and `Rails.cache.exist?` work with this store without any extra setup — no need to run `rails dev:cache`. In production, the app is pre-configured to use Solid Cache (database-backed, already in the Gemfile).

---

## If This Were Production

1. **Rate limiting / Nominatim ToS compliance** — Nominatim requires a `User-Agent` header and discourages heavy use. In production I would switch Geocoder to a paid provider (e.g., Google Maps, Mapbox) or self-host a geocoder.
2. **Background cache warm-up** — Pre-fetch and refresh cached forecasts before expiry using Solid Queue (already in the Gemfile), so users always see a fast response.
3. **Error monitoring** — Add Sentry or similar to capture `GeocodingService::NotFoundError` and `WeatherService::FetchError` in production.
4. **Internationalisation** — Temperature units could be toggled (°C / °F) based on the user's locale.
5. **More test coverage** — Integration tests with VCR cassettes would lock in the exact API response shape, guarding against upstream changes.
