class AddRequestDeadlineToShiftMonths < ActiveRecord::Migration[7.1]
  def change
    add_column :shift_months, :request_deadline, :date
  end
end
