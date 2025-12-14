class CreateShiftMonths < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_months do |t|
      t.integer :year
      t.integer :month
      t.integer :required_day_shifts
      t.string :status

      t.timestamps
    end
  end
end
