require 'rails_helper'

RSpec.describe ScraperController, type: :controller do
  describe 'GET #index' do
    subject! { get :index }

    it 'returns a successful response' do
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #data' do
    let(:valid_url) { 'https://www.alza.cz/aeg-7000-prosteam-lfr73964cc-d7635493.htm' }
    let(:valid_fields) do
      '{"price":".price-box__primary-price__value",
      "rating_count":".ratingCount",
      "rating_value":".ratingValue","meta":["keywords","twitter:image"]}'
    end
    let(:parsed_fields) do
      {
        'price' => '.price-box__primary-price__value',
        'rating_count' => '.ratingCount',
        'rating_value' => '.ratingValue',
        'meta' => [ 'keywords', 'twitter:image' ]
      }
    end
    let(:scraper_result) do
      {
        'price' => '19 990',
        'rating_count' => '25 hodnocení',
        'rating_value' => '4,8',
        'meta' => {
          'keywords' => 'AEG,7000,ProSteam®,LFR73964CC,Automatické pračky,Automatické pračky AEG',
          'twitter:image' => 'https://image.alza.cz/products/AEGPR065/AEGPR065.jpg?width=360&height=360'
        }
      }
    end

    subject { get :data, params: params }

    context 'with valid parameters' do
      let(:params) { { url: valid_url, fields: valid_fields } }
      let(:scraper_service) { instance_double(ScraperService) }

      before do
        allow(ScraperService).to receive(:new).with(valid_url, parsed_fields).and_return(scraper_service)
        allow(scraper_service).to receive(:call).and_return(scraper_result)
      end

      it 'calls ScraperService with correct params' do
        subject

        expect(ScraperService).to have_received(:new).with(valid_url, parsed_fields)
        expect(scraper_service).to have_received(:call)
      end

      it 'renders the scraper result as JSON' do
        subject

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(scraper_result.stringify_keys)
      end
    end

    context 'with missing url' do
      let(:params) { { url: '', fields: valid_fields } }

      it 'renders error for missing URL' do
        subject

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => ScraperController::ERROR_MESSAGE })
      end
    end

    context 'with missing fields' do
      let(:params) { { url: valid_url, fields: '' } }

      it 'renders error for missing fields' do
        subject

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => ScraperController::ERROR_MESSAGE })
      end
    end

    context 'with invalid JSON in fields' do
      let(:params) { { url: valid_url, fields: 'invalid json' } }

      before { allow(JSON).to receive(:parse).with('invalid json').and_raise(JSON::ParserError.new('invalid JSON')) }

      it 'renders JSON parsing error' do
        subject

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq({ "error": "Invalid JSON: invalid JSON" }.to_json)
      end
    end

    context 'when ScraperService raises a StandardError' do
      let(:params) { { url: valid_url, fields: valid_fields } }
      let(:error_message) { 'Something went wrong' }
      let(:scraper_service) { instance_double(ScraperService) }

      before do
        allow(JSON).to receive(:parse).with(valid_fields).and_return(parsed_fields)
        allow(ScraperService).to receive(:new).with(valid_url, parsed_fields).and_return(scraper_service)
        allow(scraper_service).to receive(:call).and_raise(StandardError.new(error_message))
      end

      it 'renders Internal Server error' do
        subject

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to eq({ 'error' => error_message }.to_json)
      end
    end
  end
end
