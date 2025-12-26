class ShiftMonth < ApplicationRecord
  validates :year, :month, :required_day_shifts, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, uniqueness: { scope: :month }
end
