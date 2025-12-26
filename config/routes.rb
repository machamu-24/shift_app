Rails.application.routes.draw do
  resources :staffs
  resources :shift_months, only: [:new, :create, :show] do
    post :generate, on: :member
    post :toggle_assignment, on: :member
    get :export_csv, on: :member
    get :export_pdf, on: :member
    resources :shift_requests, only: [:create, :destroy]
  end

  root "shift_months#new"
end
