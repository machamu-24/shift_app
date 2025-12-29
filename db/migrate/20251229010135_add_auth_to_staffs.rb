class AddAuthToStaffs < ActiveRecord::Migration[7.1]
  def change
    add_column :staffs, :email, :string
    add_index :staffs, :email
    add_column :staffs, :password_digest, :string
    add_column :staffs, :role, :integer, default: 0, null: false
  end
end
