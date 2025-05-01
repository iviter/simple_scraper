class ScraperController < ApplicationController
  ERROR_MESSAGE = "URL and fields are required".freeze

  def index; end

  def data
    url = scraper_params[:url]
    fields = parsed_fields(scraper_params[:fields])

    return render_error(ERROR_MESSAGE, :bad_request) if url.blank? || fields.blank?

    result = ScraperService.new(url, fields).call
    render json: result
  rescue JSON::ParserError => e
    render_error("Invalid JSON: #{e.message}", :bad_request)
  rescue StandardError => e
    render_error(e.message, :internal_server_error)
  end

  private

  def scraper_params
    params.permit(:url, :fields)
  end

  def parsed_fields(input_fields)
    JSON.parse(input_fields) if input_fields.present?
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end
end
