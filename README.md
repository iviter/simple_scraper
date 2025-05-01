# Simple Scraper

`Simple Scraper` is a Ruby on Rails app that scrapes HTML content from a specified URL using CSS selectors or meta tags. It supports both programmatic usage and a simple web interface

## Features

- Scrapes HTML content using Nokogiri.
- Supports CSS selector-based and meta tag extraction.
- Caches fetched HTML responses to optimize performance.
- Includes a minimal web UI for quick manual testing.

## Installation

1. Add the required gems in your `Gemfile`:

    ```ruby
    gem 'redis'
    gem 'rspec-rails'
    gem 'nokogiri'
    gem 'faraday'
    ```

2. Install the gems:

    ```bash
    bundle install
    ```

## Instructions

1. Start your Rails server:

    ```bash
    rails s
    ```

2. Visit the root page to open the scraper form
3. Submit a scrape request:
   - Enter a valid URL (e.g `https://example.com`).
   - Provide a JSON object for the fields to scrape (e.g `{"rating_count": ".ratingCount", "meta": ["keywords"]}`)
4. Click **“Scrape”** to view the result

## Testing

Run the test suite using RSpec:

```bash
bundle exec rspec
```
