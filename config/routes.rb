Rails.application.routes.draw do
  get "/", to: "scraper#index"
  get "/data", to: "scraper#data"
end
