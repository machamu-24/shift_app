require "test_helper"

class ShiftRequestTest < ActiveSupport::TestCase
  def setup
    @staff = Staff.create!(name: "Test Staff", email: "test@example.com", password: "password", password_confirmation: "password")
    @shift_month = ShiftMonth.create!(
      year: 2026, 
      month: 5, 
      required_day_shifts: 10,
      max_consecutive_work_days: 5,
      required_day_shifts_weekday: 5,
      required_day_shifts_sun_holiday: 5
    )
    @shift_request = ShiftRequest.new(
      staff: @staff,
      shift_month: @shift_month,
      date: Date.new(2026, 5, 1),
      kind: "off"
    )
  end

  test "should be valid" do
    assert @shift_request.valid?
  end

  test "date should be present" do
    @shift_request.date = nil
    assert_not @shift_request.valid?
  end

  test "kind should be present" do
    @shift_request.kind = nil
    assert_not @shift_request.valid?
  end

  test "should not allow duplicates for same staff, month and date" do
    @shift_request.save
    duplicate = @shift_request.dup
    assert_not duplicate.valid?
  end

  test "date must be within the shift month" do
    @shift_request.date = Date.new(2026, 4, 30) # Previous month
    assert_not @shift_request.valid?
    assert_includes @shift_request.errors[:date], "は対象月の範囲内で指定してください"

    @shift_request.date = Date.new(2026, 6, 1) # Next month
    assert_not @shift_request.valid?
  end
end
