Rails.application.routes.draw do
  resources :staffs, only: [:index, :new, :create, :edit, :update] do
    collection do
      patch :reorder
    end
  end
  resources :shift_months, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    post :generate, on: :member
    post :toggle_assignment, on: :member
    get :export_csv, on: :member
    get :export_pdf, on: :member
    resources :shift_requests, only: [:create, :destroy]
    resources :my_requests, only: [:index, :create, :destroy]
    patch :confirm, on: :member
  end

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  root "shift_months#index"
end
