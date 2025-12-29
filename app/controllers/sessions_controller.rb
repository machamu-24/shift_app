class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    staff = Staff.find_by(email: params[:email])
    if staff&.authenticate(params[:password])
      session[:staff_id] = staff.id
      redirect_to root_path, notice: "ログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:staff_id] = nil
    redirect_to login_path, notice: "ログアウトしました。"
  end
end
