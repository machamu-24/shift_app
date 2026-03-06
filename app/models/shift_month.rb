class ShiftMonth < ApplicationRecord
  validates :year, :month, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, uniqueness: { scope: :month }
  
  has_many :shift_assignments, dependent: :destroy
  has_many :shift_requests, dependent: :destroy

  before_validation :set_default_required_day_shifts, on: :create

  validates :max_consecutive_work_days,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 31 }
  validates :required_day_shifts_weekday,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :required_day_shifts_sun_holiday,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def label
    "#{year}年#{month}月"
  end

  # 希望休申請の締め切り日を過ぎているか（未設定の場合は常に申請可）
  def request_deadline_passed?
    return false if request_deadline.nil?
    Date.current > request_deadline
  end

  # ステータスの表示用ラベル
  def status_label
    if is_confirmed
      "確定済み"
    elsif status == "generated"
      "仮シフト"
    else
      "未生成"
    end
  end

  # ステータスの色クラス
  def status_color
    if is_confirmed
      "status-confirmed"
    elsif status == "generated"
      "status-generated"
    else
      "status-draft"
    end
  end

  def holiday_for_minimum_rest?(date)
    date.saturday? || date.sunday? || HolidayJapan.check(date)
  end

  def sun_or_holiday?(date)
    date.sunday? || HolidayJapan.check(date)
  end

  def required_for(date)
    sun_or_holiday?(date) ? required_day_shifts_sun_holiday : required_day_shifts_weekday
  end

  private

  def set_default_required_day_shifts
    self.required_day_shifts ||= 0
  end
end
