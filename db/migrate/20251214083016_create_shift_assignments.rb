class CreateShiftAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_assignments do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :shift_month, null: false, foreign_key: true
      t.date :date, null: false
      t.string :kind, null: false

      t.timestamps
    end

    add_index :shift_assignments, [:staff_id, :shift_month_id, :date], unique: true
  end
end
