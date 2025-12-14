class CreateStaffs < ActiveRecord::Migration[7.1]
  def change
    create_table :staffs do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
