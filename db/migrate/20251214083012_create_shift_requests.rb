class CreateShiftRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_requests do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :shift_month, null: false, foreign_key: true
      t.date :date
      t.string :kind

      t.timestamps
    end
  end
end
