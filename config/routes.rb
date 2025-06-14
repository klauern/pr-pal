Rails.application.routes.draw do
  get "settings", to: "settings#index"
  patch "settings", to: "settings#update"
  resources :repositories, only: [ :index, :show, :new, :create, :destroy ] do
    member do
      post :sync
    end
    collection do
      post :sync_all
    end
  end
  resources :pull_request_reviews, only: [ :index, :show, :create, :update, :destroy ] do
    resources :llm_conversation_messages, only: [ :create ]
    member do
      post :sync
    end
    collection do
      get :show_by_details
      post :reset_tabs
    end
    post "reset_conversation", to: "llm_conversation_messages#reset"
  end


  get "dashboard/index"
  # Remove the default resource :session route and add custom routes for session actions
  # resource :session
  get "/demo_login", to: "sessions#new", as: :demo_login
  post "/session", to: "sessions#create", as: :session
  delete "/session", to: "sessions#destroy"

  # Registration routes
  get "/sign_up", to: "registrations#new", as: :new_registration
  post "/registrations", to: "registrations#create", as: :registrations
  resources :passwords, param: :token

  # PR tab management
  delete "/close_pr_tab", to: "pull_request_reviews#close_tab", as: :close_pr_tab

  # Debug route to reset session tabs
  get "/reset_tabs", to: "pull_request_reviews#reset_tabs", as: :reset_tabs

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

  get "/repos/:repo_owner/:repo_name/reviews/:pr_number", to: "pull_request_reviews#show_by_details", as: :direct_pr_review

  resources :settings, only: [ :index, :update ] do
    collection do
      post :add_llm_api_key
      post :update_llm_api_key
      delete :delete_llm_api_key
      post :update_llm_preferences
    end
  end
end
