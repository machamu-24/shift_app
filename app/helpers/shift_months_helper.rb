module ShiftMonthsHelper
  def dom_id_for_cell(shift_month, staff, date)
    "cell_sm#{shift_month.id}_st#{staff.id}_d#{date.strftime('%Y%m%d')}"
  end

  def dom_id_for_row(shift_month, staff)
    "row_sm#{shift_month.id}_st#{staff.id}"
  end
  

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def holiday?(date)
    HolidayJapan.check(date)
  end

  def holiday_name(date)
    HolidayJapan.name(date)
  end

  def date_header_class(date)
    return "col-holiday" if holiday?(date)
    return "col-sun" if date.sunday?
    return "col-sat" if date.saturday?
    ""
  end

  def consecutive_work_span_if_set_to_work(assignment_map, staff_id, date)
    # date を D にしたと仮定した時の「連続D」の長さ（前後を含む）
    left = 0
    d = date - 1
    while true
      a = assignment_map.dig(staff_id, d)
      break unless a&.kind == "D"
      left += 1
      d -= 1
    end
  
    right = 0
    d = date + 1
    while true
      a = assignment_map.dig(staff_id, d)
      break unless a&.kind == "D"
      right += 1
      d += 1
    end
  
    left + 1 + right
  end
  
end
