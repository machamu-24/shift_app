Rails.application.routes.draw do
  resources :staffs
  resources :shift_months, only: [:new, :create, :show] do
    post :generate, on: :member
  end

  root "shift_months#new"
end
