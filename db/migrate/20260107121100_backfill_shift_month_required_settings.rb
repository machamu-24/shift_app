class BackfillShiftMonthRequiredSettings < ActiveRecord::Migration[7.1]
  def up
    ShiftMonth.reset_column_information
    ShiftMonth.find_each do |sm|
      next if sm.required_day_shifts.nil?

      sm.update_columns(
        required_day_shifts_weekday: sm.required_day_shifts,
        required_day_shifts_sun_holiday: sm.required_day_shifts
      )
    end
  end

  def down
    # no-op
  end
end
