require "nokogiri"

class ScraperService
  def initialize(url, fields)
    @url = url
    @fields = fields
    @cache_key = "scraper:#{Digest::MD5.hexdigest(url)}"
  end

  def call
    document = Nokogiri::HTML(fetch_html)
    build_result(document)
  end

  private

  attr_reader :url, :fields, :cache_key

  def fetch_html
    cached_page = Rails.cache.read(cache_key)
    return cached_page if cached_page

    response = Faraday.get(url)

    raise "Failed to fetch URL: #{url}" unless response.success?

    Rails.cache.write(cache_key, response.body)
    response.body
  end

  def build_result(document)
    result = {}

    fields.each do |key, value|
      if key == "meta"
        result[key] = fetch_meta(document, value)
      else
        result[key] = fetch_css(document, value)
      end
    end

    result
  end

  def fetch_meta(document, meta_names)
    result = {}

    meta_names.each do |name|
      meta_tag = document.css("meta[name='#{name}'], meta[property='#{name}']")
      result[name] = meta_tag.attribute("content")&.value
    end

    result
  end

  def fetch_css(document, selector)
    element = document.css(selector)
    element&.text&.strip || ""
  end
end
