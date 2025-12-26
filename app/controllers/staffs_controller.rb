class StaffsController < ApplicationController
  def index
    @staffs = Staff.order(active: :desc, id: :asc)
  end

  def new
    @staff = Staff.new(active: true)
  end

  def create
    @staff = Staff.new(staff_params)
    if @staff.save
      redirect_to staffs_path, notice: "スタッフを追加しました。"
    else
      flash.now[:alert] = @staff.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @staff = Staff.find(params[:id])
  end

  def update
    @staff = Staff.find(params[:id])
    if @staff.update(staff_params)
      redirect_to staffs_path, notice: "スタッフ情報を更新しました。"
    else
      flash.now[:alert] = @staff.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def staff_params
    params.require(:staff).permit(:name, :active)
  end
end
