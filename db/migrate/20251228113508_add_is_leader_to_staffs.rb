class AddIsLeaderToStaffs < ActiveRecord::Migration[7.1]
  def change
    add_column :staffs, :is_leader, :boolean, default: false, null: false
  end
end
