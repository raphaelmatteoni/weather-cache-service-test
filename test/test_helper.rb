ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Geocoder ships with a test lookup that lets tests control geocoding results
# without making real network calls.
Geocoder.configure(lookup: :test)

module ActiveSupport
  class TestCase
    # Clears cached geocoding fixtures between tests so they don't leak.
    setup { Geocoder::Lookup::Test.reset }
  end
end
