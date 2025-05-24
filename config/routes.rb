Rails.application.routes.draw do
  get "dashboard/index"
  # Remove the default resource :session route and add custom routes for session actions
  # resource :session
  get "/demo_login", to: "sessions#new", as: :demo_login
  post "/session", to: "sessions#create", as: :session
  delete "/session", to: "sessions#destroy"
  resources :passwords, param: :token

  # Hotwire sidebar/tab routes
  resource :tabs, only: [] do
    post :open_pr, on: :collection
    post :close_pr, on: :collection
    get :select_tab, on: :collection
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end
