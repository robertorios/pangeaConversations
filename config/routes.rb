Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Real-Time Communication Endpoint ---
  # Mounts the Action Cable server, allowing clients to connect via WebSockets at /cable
  mount ActionCable.server => '/cable'

  # --- WebSocket Monitoring Endpoints ---
  get '/websocket/status', to: 'websocket_monitor#index'
  get '/websocket/stats', to: 'websocket_monitor#stats'
  post '/websocket/stop_all', to: 'websocket_monitor#stop_all'
  post '/websocket/stop_user/:user_id', to: 'websocket_monitor#stop_user'
  post '/websocket/pause', to: 'websocket_monitor#pause'
  post '/websocket/resume', to: 'websocket_monitor#resume'
  
  # --- Dynamic Channel Registration ---
  post '/channels/register', to: 'channels#register'
  get '/channels/list', to: 'channel_registration#list'

  # --- API Endpoints for Message History ---
  # Namespaced for versioning (api/v1)
  namespace :api do
    namespace :v1 do
      # Since we don't need all RESTful actions for a single conversation resource, 
      # we use `only: []` and define a custom collection action `history`.
      resources :conversations, only: [] do
        collection do
          # GET /api/v1/conversations/history
          get :history 
          # get :user_conversations
          get 'user/:user_id', to: 'conversations#user_conversations', as: :user_conversations
        end
      end
      
      # NOTE: We will add a route here later to handle saving Push Tokens (e.g., resources :push_tokens)
    end
  end
  # Defines the root path route ("/")
  # root "posts#index"
end
