Staff.destroy_all

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

Staff.create!(
  name: "管理者",
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password",
  role: :admin,
  is_leader: true
)

names.each_with_index do |name, index|
  Staff.create!(
    name: name,
    email: "staff#{index + 1}@example.com",
    password: "password",
    password_confirmation: "password",
    role: :general
  )
end

puts "Admin seed created: 1"
puts "Staff seeds created: #{names.size}"

