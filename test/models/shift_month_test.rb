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

  test "request_deadline_passed? returns false when deadline is nil" do
    @shift_month.request_deadline = nil
    assert_not @shift_month.request_deadline_passed?
  end

  test "request_deadline_passed? returns false when deadline is today" do
    @shift_month.request_deadline = Date.current
    assert_not @shift_month.request_deadline_passed?
  end

  test "request_deadline_passed? returns true when deadline is yesterday" do
    @shift_month.request_deadline = Date.current - 1
    assert @shift_month.request_deadline_passed?
  end

  test "request_deadline_passed? returns false when deadline is tomorrow" do
    @shift_month.request_deadline = Date.current + 1
    assert_not @shift_month.request_deadline_passed?
  end

  test "status_label returns correct label for draft" do
    @shift_month.status = "draft"
    @shift_month.is_confirmed = false
    assert_equal "未生成", @shift_month.status_label
  end

  test "status_label returns correct label for generated" do
    @shift_month.status = "generated"
    @shift_month.is_confirmed = false
    assert_equal "仮シフト", @shift_month.status_label
  end

  test "status_label returns correct label for confirmed" do
    @shift_month.status = "generated"
    @shift_month.is_confirmed = true
    assert_equal "確定済み", @shift_month.status_label
  end

  test "status_color returns correct class for draft" do
    @shift_month.status = "draft"
    @shift_month.is_confirmed = false
    assert_equal "status-draft", @shift_month.status_color
  end

  test "status_color returns correct class for generated" do
    @shift_month.status = "generated"
    @shift_month.is_confirmed = false
    assert_equal "status-generated", @shift_month.status_color
  end

  test "status_color returns correct class for confirmed" do
    @shift_month.status = "generated"
    @shift_month.is_confirmed = true
    assert_equal "status-confirmed", @shift_month.status_color
  end
end
