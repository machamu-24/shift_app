class AddShiftSettingsToShiftMonths < ActiveRecord::Migration[7.1]
  def change
    add_column :shift_months, :max_consecutive_work_days, :integer, null: false, default: 5
    add_column :shift_months, :required_day_shifts_weekday, :integer, null: false, default: 0
    add_column :shift_months, :required_day_shifts_sun_holiday, :integer, null: false, default: 0
  end
end
