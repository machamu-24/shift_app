class ShiftRequest < ApplicationRecord
  belongs_to :staff
  belongs_to :shift_month

  validates :date, presence: true
  validates :kind, presence: true
  validates :staff_id, uniqueness: { scope: [:shift_month_id, :date], message: "は同じ日に重複登録できません" }

  validate :date_must_be_within_month

  private

  def date_must_be_within_month
    return if date.blank? || shift_month.blank?

    start_date = Date.new(shift_month.year, shift_month.month, 1)
    end_date   = start_date.end_of_month

    unless (start_date..end_date).cover?(date)
      errors.add(:date, "は対象月の範囲内で指定してください")
    end
  end
end
