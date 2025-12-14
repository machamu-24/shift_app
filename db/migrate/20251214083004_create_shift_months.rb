class CreateShiftMonths < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_months do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :required_day_shifts, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
  end
end
