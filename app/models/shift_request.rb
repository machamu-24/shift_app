class ShiftRequest < ApplicationRecord
  belongs_to :staff
  belongs_to :shift_month
end
