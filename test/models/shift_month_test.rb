require "test_helper"

class ShiftMonthTest < ActiveSupport::TestCase
  def setup
    @shift_month = ShiftMonth.new(
      year: 2026,
      month: 2,
      required_day_shifts: 10,
      max_consecutive_work_days: 5,
      required_day_shifts_weekday: 5,
      required_day_shifts_sun_holiday: 5
    )
  end

  test "should be valid" do
    assert @shift_month.valid?
  end

  test "year and month should be present" do
    @shift_month.year = nil
    assert_not @shift_month.valid?
    @shift_month.year = 2026

    @shift_month.month = nil
    assert_not @shift_month.valid?
  end

  test "month should be within 1 to 12" do
    @shift_month.month = 0
    assert_not @shift_month.valid?
    @shift_month.month = 13
    assert_not @shift_month.valid?
    @shift_month.month = 12
    assert @shift_month.valid?
  end

  test "year and month combination should be unique" do
    duplicate = @shift_month.dup
    @shift_month.save
    assert_not duplicate.valid?
  end

  test "label returns formatted string" do
    assert_equal "2026年2月", @shift_month.label
  end

  test "holiday_for_minimum_rest returns true for sunday" do
    sunday = Date.new(2026, 2, 1) # 2026/2/1 is Sunday
    assert @shift_month.holiday_for_minimum_rest?(sunday)
  end

  test "holiday_for_minimum_rest returns true for saturday" do
    saturday = Date.new(2026, 2, 7)
    assert @shift_month.holiday_for_minimum_rest?(saturday)
  end

  test "required_for returns correct count based on holiday" do
    @shift_month.required_day_shifts_weekday = 5
    @shift_month.required_day_shifts_sun_holiday = 3

    friday = Date.new(2026, 2, 6)
    sunday = Date.new(2026, 2, 1)

    assert_equal 5, @shift_month.required_for(friday)
    assert_equal 3, @shift_month.required_for(sunday)
  end
end
