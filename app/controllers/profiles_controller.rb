class ProfilesController < ApplicationController
  def edit
    @staff = current_staff
  end

  def update
    @staff = current_staff
    if @staff.update(profile_params)
      redirect_to shift_months_path, notice: "プロフィールを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:staff).permit(:email, :password, :password_confirmation, :name)
  end
end
