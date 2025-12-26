class AddUniqueIndexToShiftMonthsYearMonth < ActiveRecord::Migration[7.1]
  def change
    add_index :shift_months, %i[year month], unique: true, name: "index_shift_months_on_year_and_month_unique"
  end
end
