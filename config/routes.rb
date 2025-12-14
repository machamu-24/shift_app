Rails.application.routes.draw do
  get 'shift_months/new'
  get 'shift_months/create'
  get 'shift_months/show'
  get 'staffs/index'
  get 'staffs/new'
  get 'staffs/create'
  get 'staffs/edit'
  get 'staffs/update'
  get 'staffs/destroy'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
