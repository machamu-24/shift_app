class AddIsConfirmedToShiftMonths < ActiveRecord::Migration[7.1]
  def change
    add_column :shift_months, :is_confirmed, :boolean, default: false, null: false
  end
end
