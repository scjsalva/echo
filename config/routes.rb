Rails.application.routes.draw do
  root "dashboard#show"

  resource :settings, only: :show
  resources :agents, only: :index
  resources :loops, only: :index
  get "jira", to: "jira#index"
  get "github", to: "github#index"
  get "reviews/:owner/:repo/:number", to: "reviews#show", as: :review_page, constraints: { owner: /[\w.-]+/, repo: /[\w.-]+/, number: /\d+/ }
  get "inbox", to: "inbox#index"
  get "sounds/:name", to: "sounds#show", as: :sound, constraints: { name: /[A-Za-z]+/ }

  namespace :api do
    resource :dashboard, only: :show
    resources :agents, only: :index do
      resource :transcript, only: :show
      resource :summary, only: :create
      resource :focus, only: :create
      resource :rename, only: :create
      resource :ending, only: :create
    end
    resources :ended_sessions, only: :index do
      resource :resume, only: :create
    end
    resources :dismissals, only: %i[create destroy], param: :item_key
    resources :notifications, only: :index do
      patch :read, on: :member
      post :read_all, on: :collection
    end
    resource :settings, only: :update
    resource :test_notification, only: :create
    resources :alerts, only: :index
    resources :hooks, only: :create
    resource :changes, only: :show
    resources :github_pull_requests, only: :index, path: "github/pull_requests"
    resource :github_echo_copy, only: :destroy, path: "github/echo_copy"
    resource :skill, only: %i[show update]
    resource :claude_context, only: :update
    scope "cli", controller: "cli", as: "cli" do
      get :status
      get :summary
      get :waiting
      get :inbox
      get :prs
      get :agents
      get :mine
      get :pr
      get "jira/:key", action: :ticket
      post :read
      post :dismiss
      post :focus
      post :reviews, action: :start_review
      get "reviews/:id", action: :show_review
    end
    get "github/pull_requests/:owner/:repo/:number/threads", to: "github_review_threads#index", constraints: { owner: /[\w.-]+/, repo: /[\w.-]+/, number: /\d+/ }
    get "github/pull_requests/:owner/:repo/:number/comments", to: "github_pull_request_comments#index", constraints: { owner: /[\w.-]+/, repo: /[\w.-]+/, number: /\d+/ }
    resources :reviews, only: :show do
      resource :ai_review, only: :create
      resource :submission, only: :create, controller: "review_submissions"
      resources :comments, only: :create, controller: "review_comments"
    end
    resources :review_comments, only: :update do
      resource :question, only: :create, controller: "review_questions"
    end
    namespace :jira do
      resources :tickets, only: %i[index show], param: :key
      resources :done_tickets, only: :index
      resource :search, only: :show
    end
    resources :connections, only: %i[index destroy], param: :key do
      resource :setup, only: :create, controller: "connection_setups"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
