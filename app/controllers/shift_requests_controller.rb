class ShiftRequestsController < ApplicationController
  def create
    shift_month = ShiftMonth.find(params[:shift_month_id])

    shift_request = ShiftRequest.new(shift_request_params.merge(
      shift_month_id: shift_month.id,
      kind: "off"
    ))

    if shift_request.save
      redirect_to shift_month, notice: "希望休を追加しました"
    else
      # 失敗理由を短く表示（重複・未入力など）
      redirect_to shift_month, alert: shift_request.errors.full_messages.join(" / ")
    end
  end

  def destroy
    shift_month = ShiftMonth.find(params[:shift_month_id])
    shift_request = ShiftRequest.find(params[:id])

    shift_request.destroy
    redirect_to shift_month, notice: "希望休を削除しました"
  end

  private

  def shift_request_params
    params.require(:shift_request).permit(:staff_id, :date)
  end
end
