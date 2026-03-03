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

  validates :kind, inclusion: { in: KINDS.values }
end
