names = %w[
  佐藤
  鈴木
  高橋
  田中
  伊藤
  渡辺
  山本
  中村
  小林
  加藤
  吉田
  山田
  佐々木
  山口
  松本
  井上
  木村
  林
  斎藤
  清水
]

admin = Staff.find_or_initialize_by(email: "admin@example.com")
admin.name = "管理者"
admin.password = "password"
admin.password_confirmation = "password"
admin.role = :admin
admin.is_leader = true
admin.save!

names.each_with_index do |name, index|
  Staff.find_or_create_by!(email: "staff#{index + 1}@example.com") do |staff|
    staff.name = name
    staff.password = "password"
    staff.password_confirmation = "password"
    staff.role = :general
  end
end

puts "Seed data integration complete! (Existing data was not deleted)"
