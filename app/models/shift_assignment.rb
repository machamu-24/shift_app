class ShiftAssignment < ApplicationRecord
  belongs_to :staff
  belongs_to :shift_month

  KINDS = {
    "D" => "D",
    "O" => "O",
    "nen" => "nen",
    "time_4_8" => "time_4_8",
    "time_3_8" => "time_3_8",
    "time_2_8" => "time_2_8",
    "time_1_8" => "time_1_8",
    "kousei" => "kousei"
  }.freeze

  HUMAN_KINDS = {
    "D" => "",
    "O" => "休",
    "nen" => "年",
    "time_4_8" => "4/8",
    "time_3_8" => "3/8",
    "time_2_8" => "2/8",
    "time_1_8" => "1/8",
    "kousei" => "厚"
  }.freeze

  # 分数休暇の分子（分母は8）
  FRACTION_NUMERATORS = {
    "time_4_8" => 4,
    "time_3_8" => 3,
    "time_2_8" => 2,
    "time_1_8" => 1
  }.freeze

  validates :kind, inclusion: { in: KINDS.values }

  # 出勤扱いかどうか（分数休暇も出勤扱い）
  def self.work_kind?(kind)
    kind == "D" || FRACTION_NUMERATORS.key?(kind)
  end

  # 休み扱いかどうか（O, nen, kousei）
  def self.off_kind?(kind)
    kind == "O" || kind == "nen" || kind == "kousei"
  end

  # 年休・厚休かどうか
  def self.special_leave_kind?(kind)
    kind == "nen" || kind == "kousei"
  end

  # kindの配列から休日合計日数を計算する
  # 分数休暇は合計して8/8以上になったら1日としてカウント（端数切り捨て）
  def self.calculate_holiday_count(kinds)
    off_days = kinds.count { |k| off_kind?(k) }
    fraction_sum = kinds.sum { |k| FRACTION_NUMERATORS.fetch(k, 0) }
    fraction_days = fraction_sum / 8  # 整数除算（端数切り捨て）
    off_days + fraction_days
  end

  # kindの配列から年休・厚休合計日数を計算する
  def self.calculate_special_leave_count(kinds)
    kinds.count { |k| special_leave_kind?(k) }
  end
end
