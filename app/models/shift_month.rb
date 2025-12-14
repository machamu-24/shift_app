class ShiftMonth < ApplicationRecord
  validates :year, :month, :required_day_shifts, presence: true
end
