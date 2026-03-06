class MyRequestsController < ApplicationController
  before_action :set_shift_month

  def index
    @requests = @shift_month.shift_requests.where(staff_id: current_staff.id).order(:date)
    @new_request = @shift_month.shift_requests.build(staff_id: current_staff.id)
  end

  def create
    if @shift_month.request_deadline_passed?
      redirect_to shift_month_my_requests_path(@shift_month), alert: "申請期限（#{@shift_month.request_deadline}）を過ぎているため、希望休の申請はできません。"
      return
    end

    @request = @shift_month.shift_requests.build(request_params)
    @request.staff_id = current_staff.id # 念のため強制上書き

    if @request.save
      redirect_to shift_month_my_requests_path(@shift_month), notice: "希望休を追加しました。"
    else
      redirect_to shift_month_my_requests_path(@shift_month), alert: @request.errors.full_messages.to_sentence
    end
  end

  def destroy
    @request = @shift_month.shift_requests.where(staff_id: current_staff.id).find(params[:id])
    @request.destroy
    redirect_to shift_month_my_requests_path(@shift_month), notice: "希望休を削除しました。"
  end

  private

  def set_shift_month
    @shift_month = ShiftMonth.find(params[:shift_month_id])
  end

  def request_params
    params.require(:shift_request).permit(:date)
  end
end
