Rails.application.routes.draw do
  resources :staffs, only: [:index, :new, :create, :edit, :update]
  resources :shift_months, only: [:index, :new, :create, :show] do
    post :generate, on: :member
    post :toggle_assignment, on: :member
    get :export_csv, on: :member
    get :export_pdf, on: :member
    resources :shift_requests, only: [:create, :destroy]
  end

  root "shift_months#new"
end
