module ShiftMonthsHelper
  def dom_id_for_cell(shift_month, staff, date)
    "cell_sm#{shift_month.id}_st#{staff.id}_d#{date.strftime('%Y%m%d')}"
  end
end
