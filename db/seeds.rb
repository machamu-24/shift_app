Staff.destroy_all

names = %w[
  佐藤
  鈴木
  高橋
  田中
  伊藤
  渡辺
]

names.each do |name|
  Staff.create!(name: name)
end

puts "Staff seeds created: #{Staff.count}"

