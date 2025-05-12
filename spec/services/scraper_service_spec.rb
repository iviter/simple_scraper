require 'rails_helper'

RSpec.describe ScraperService do
  let(:url) { 'https://example.com' }
  let(:fields) { { 'title' => 'h1', 'meta' => [ 'description', 'keywords' ] } }
  let(:cache_key) { "scraper:#{Digest::MD5.hexdigest(url)}" }
  let(:service) { described_class.new(url, fields) }
  let(:html_content) do
    '<html><h1>Hello</h1><meta name="description" content="A page"><meta name="keywords" content="test"></html>'
  end

  describe '#call' do
    subject { service.call }

    before { allow(service).to receive(:build_result).and_return({}) }

    it 'calls build_result method' do
      subject

      expect(service).to have_received(:build_result)
    end
  end

  describe '#build_result' do
    let(:mock_document) { instance_double(Nokogiri::HTML4::Document) }

    subject { service.send(:build_result, mock_document) }

    context 'with generic fields' do
      before do
        allow(service).to receive(:fetch_html).and_return(html_content)
        allow(Nokogiri).to receive(:HTML).and_return(mock_document)
        allow(service).to receive(:fetch_css).with(mock_document, 'h1').and_return('Hello')
        allow(service).to receive(:fetch_meta).with(mock_document, [ 'description', 'keywords' ]).and_return({
          'description' => 'A page', 'keywords' => 'test' })
      end

      it 'processes fields and returns scraped data' do
        expect(subject).to eq({ 'title' => 'Hello', 'meta' => { 'description' => 'A page', 'keywords' => 'test' } })
        expect(service).to have_received(:fetch_css).with(mock_document, 'h1').once
        expect(service).to have_received(:fetch_meta).with(mock_document, [ 'description', 'keywords' ]).once
      end
    end

    context 'with Alza.cz product page fields' do
      let(:url) { 'https://www.alza.cz/aeg-7000-prosteam-lfr73964cc-d7635493.htm' }
      let(:fields) do
        {
          'price' => '.price-box__primary-price__value',
          'rating_count' => '.ratingCount',
          'rating_value' => '.ratingValue',
          'meta' => [ 'keywords', 'twitter:image' ]
        }
      end
      let(:html_content) do
        <<-HTML
          <html>
            <body>
              <span class="price-box__primary-price__value">19 990,-641,-</span>
              <span class="ratingCount">25 hodnocení</span>
              <span class="ratingValue">4,8</span>
              <meta name="keywords" content="AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG">
              <meta name="twitter:image" content="https://image.alza.cz/products/AEGPR065.jpg?width=360&height=360">
            </body>
          </html>
        HTML
      end

      before do
        allow(service).to receive(:fetch_html).and_return(html_content)
        allow(Nokogiri).to receive(:HTML).and_return(mock_document)
        allow(service).to receive(:fetch_css).with(mock_document, '.price-box__primary-price__value').and_return('19 990,-641,-')
        allow(service).to receive(:fetch_css).with(mock_document, '.ratingCount').and_return('25 hodnocení')
        allow(service).to receive(:fetch_css).with(mock_document, '.ratingValue').and_return('4,8')
        allow(service).to receive(:fetch_meta).with(mock_document, [ 'keywords', 'twitter:image' ]).and_return({
          'keywords' => 'AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG',
          'twitter:image' => 'https://image.alza.cz/products/AEGPR065.jpg?width=360&height=360'
        })
      end

      it 'processes Alza.cz fields and returns scraped data' do
        expect(subject).to eq({
          'price' => '19 990,-641,-',
          'rating_count' => '25 hodnocení',
          'rating_value' => '4,8',
          'meta' => {
            'keywords' => 'AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG',
            'twitter:image' => 'https://image.alza.cz/products/AEGPR065.jpg?width=360&height=360'
          }
        })
        expect(service).to have_received(:fetch_css).with(mock_document, '.price-box__primary-price__value').once
        expect(service).to have_received(:fetch_css).with(mock_document, '.ratingCount').once
        expect(service).to have_received(:fetch_css).with(mock_document, '.ratingValue').once
        expect(service).to have_received(:fetch_meta).with(mock_document, [ 'keywords', 'twitter:image' ]).once
      end
    end
  end

  describe '#fetch_html method' do
    subject { service.send(:fetch_html) }

    context 'when content is cached' do
      before { allow(Rails.cache).to receive(:read).with(cache_key).and_return(html_content) }

      it 'returns cached content' do
        expect(subject).to eq(html_content)
        expect(Rails.cache).to have_received(:read).with(cache_key)
      end
    end

    context 'when content is not cached' do
      let(:response) { instance_double(Faraday::Response, success?: true, body: html_content) }

      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Faraday).to receive(:get).with(url).and_return(response)
        allow(Rails.cache).to receive(:write).with(cache_key, html_content)
      end

      it 'fetches and caches HTML' do
        expect(subject).to eq(html_content)
        expect(Faraday).to have_received(:get).with(url)
        expect(Rails.cache).to have_received(:write).with(cache_key, html_content)
      end
    end

    context 'when Faraday request fails' do
      let(:response) { instance_double(Faraday::Response, success?: false) }

      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Faraday).to receive(:get).with(url).and_return(response)
      end

      it 'raises an error' do
        expect { subject }.to raise_error("Failed to fetch URL: #{url}")
      end
    end
  end

  describe '#fetch_meta' do
    let(:meta_names) { [ 'keywords', 'twitter:image' ] }
    let(:mock_document) { instance_double(Nokogiri::HTML4::Document) }

    subject { service.send(:fetch_meta, mock_document, meta_names) }

    before do
      allow(mock_document).to receive(:css).with("meta[name='keywords'], meta[property='keywords']").and_return(
        instance_double(Nokogiri::XML::Element, attribute: instance_double(Nokogiri::XML::Attr,
        value: 'AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG'))
      )
      allow(mock_document).to receive(:css).with("meta[name='twitter:image'], meta[property='twitter:image']").and_return(
        instance_double(Nokogiri::XML::Element,
        attribute: instance_double(Nokogiri::XML::Attr,
        value: 'https://image.alza.cz/products/AEGPR065/AEGPR065.jpg?width=360&height=360'))
      )
    end

    it 'fetches meta tag contents' do
      expect(subject).to eq({
        'keywords' => 'AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG',
        'twitter:image' => 'https://image.alza.cz/products/AEGPR065/AEGPR065.jpg?width=360&height=360'
      })
    end

    context 'when meta tag is missing' do
      before do
        allow(mock_document).to receive(:css).with("meta[name='keywords'], meta[property='keywords']").and_return(
          instance_double(Nokogiri::XML::Element, attribute: nil)
        )
        allow(mock_document).to receive(:css).with("meta[name='twitter:image'], meta[property='twitter:image']").and_return(
          instance_double(Nokogiri::XML::Element, attribute: nil)
        )
      end

      it 'returns nil for missing meta tags' do
        expect(subject).to eq({
          'keywords' => nil,
          'twitter:image' => nil
        })
      end
    end
  end

  describe '#fetch_css' do
    let(:selector) { '.price-box__primary-price__value' }
    let(:mock_document) { instance_double(Nokogiri::HTML4::Document) }

    subject { service.send(:fetch_css, mock_document, selector) }

    before do
      allow(mock_document).to receive(:css).with(selector).and_return(
        instance_double(Nokogiri::XML::Element, text: '19 990,-641,- ')
      )
    end

    it 'fetches and strips text from CSS selector' do
      expect(subject).to eq('19 990,-641,-')
    end

    context 'when selector does not match' do
      before { allow(mock_document).to receive(:css).with(selector).and_return(nil) }

      it 'returns empty string' do
        expect(subject).to eq('')
      end
    end
  end
end
