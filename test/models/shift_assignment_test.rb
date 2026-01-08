require "test_helper"

class ShiftAssignmentTest < ActiveSupport::TestCase
  def setup
    @staff = Staff.create!(name: "Test Staff", email: "assignment@example.com", password: "password", password_confirmation: "password")
    @shift_month = ShiftMonth.create!(
      year: 2026, 
      month: 6, 
      required_day_shifts: 10,
      max_consecutive_work_days: 5,
      required_day_shifts_weekday: 5,
      required_day_shifts_sun_holiday: 5
    )
    @shift_assignment = ShiftAssignment.new(
      staff: @staff,
      shift_month: @shift_month,
      date: Date.new(2026, 6, 1),
      kind: "D"
    )
  end

  test "should be valid" do
    assert @shift_assignment.valid?
  end

  test "should belong to staff" do
    assert_equal @staff, @shift_assignment.staff
  end

  test "should belong to shift_month" do
    assert_equal @shift_month, @shift_assignment.shift_month
  end
end
