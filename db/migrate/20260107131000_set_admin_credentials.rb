class SetAdminCredentials < ActiveRecord::Migration[7.1]
  def up
    # モデルの定義情報をリセット（念のため）
    Staff.reset_column_information

    # 名前が「佐藤」のスタッフを探す（seeds.rbで作成されているはず）
    staff = Staff.find_by(name: "佐藤")

    # いなければ作成する
    staff ||= Staff.new(name: "佐藤")

    # ログイン情報を設定して保存
    # パスワードは "password123" に設定
    staff.assign_attributes(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :admin
    )
    
    staff.save!
  end

  def down
    # 戻す処理は特に不要（データ修正のため）
  end
end
