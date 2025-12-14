class ShiftMonthsController < ApplicationController
  def new
    @shift_month = ShiftMonth.new
  end

  def create
    @shift_month = ShiftMonth.new(shift_month_params.merge(status: "draft"))
    if @shift_month.save
      redirect_to @shift_month
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @shift_month = ShiftMonth.find(params[:id])
    @error_message = flash[:error_message]
    @shortages     = flash[:shortages] || []

    @assignments = ShiftAssignment
                     .includes(:staff)
                     .where(shift_month_id: @shift_month.id)
                     .order(:date, :staff_id)
  end

  def generate
    shift_month = ShiftMonth.find(params[:id])

    begin
      ShiftGenerator.new(shift_month: shift_month).call!
      redirect_to shift_month, notice: "シフトを生成しました"
    rescue NoSolutionError => e
      flash[:error_message] = e.message
      # flashはシリアライズされるのでDateは文字列にしておく
      flash[:shortages] = e.shortages.map do |h|
        h.merge(date: h[:date].to_s)
      end
      redirect_to shift_month
    end
  end

  private

  def shift_month_params
    params.require(:shift_month).permit(:year, :month, :required_day_shifts)
  end
end
