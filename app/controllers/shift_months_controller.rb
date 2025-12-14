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
    @shift_request = ShiftRequest.new
    @staffs        = Staff.where(active: true).order(:id)

    @requests = ShiftRequest
                  .includes(:staff)
                  .where(shift_month_id: @shift_month.id, kind: "off")
                  .order(:date, :staff_id)

    start_date = Date.new(@shift_month.year, @shift_month.month, 1)
    end_date   = start_date.end_of_month
    @dates     = (start_date..end_date).to_a

    assignments = ShiftAssignment
                    .where(shift_month_id: @shift_month.id)
                    .order(:date, :staff_id)

    # matrix[staff_id][date] = "D" or "O"
    @matrix = Hash.new { |h, k| h[k] = {} }
    assignments.each do |a|
      @matrix[a.staff_id][a.date] = a.kind
    end
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
