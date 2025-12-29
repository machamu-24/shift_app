class StaffsController < ApplicationController
  before_action :require_admin

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

  def reorder
    # params[:order] is an array of IDs in the new order
    if params[:order].is_a?(Array)
      Staff.transaction do
        params[:order].each_with_index do |id, index|
          Staff.where(id: id).update_all(position: index + 1)
        end
      end
    end
    head :ok
  end

  private

  def staff_params
    params.require(:staff).permit(:name, :active, :is_leader)
  end
end
