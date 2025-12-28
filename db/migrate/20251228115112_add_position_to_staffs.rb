class AddPositionToStaffs < ActiveRecord::Migration[7.1]
  def change
    add_column :staffs, :position, :integer
  end
end
