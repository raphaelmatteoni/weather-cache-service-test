class ForecastsController < ApplicationController
  def index
    return unless params[:address].present?

    result = WeatherService.call(params[:address])
    @forecast = result[:data]
    @cached   = result[:cached]
    @location = result[:location]
  rescue GeocodingService::NotFoundError => e
    flash.now[:alert] = e.message
  rescue WeatherService::FetchError => e
    flash.now[:alert] = e.message
  end
end
