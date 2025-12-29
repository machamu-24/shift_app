class ApplicationController < ActionController::Base
  helper_method :current_staff, :logged_in?

  before_action :require_login

  private

  def current_staff
    @current_staff ||= Staff.find_by(id: session[:staff_id]) if session[:staff_id]
  end

  def logged_in?
    !!current_staff
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "ログインしてください。"
    end
  end

  def require_admin
    unless current_staff&.admin?
      redirect_to root_path, alert: "権限がありません。"
    end
  end
end
