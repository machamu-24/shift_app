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

  # ===== work_kind? のテスト =====
  test "D is work kind" do
    assert ShiftAssignment.work_kind?("D")
  end

  test "time_4_8 is work kind" do
    assert ShiftAssignment.work_kind?("time_4_8")
  end

  test "time_3_8 is work kind" do
    assert ShiftAssignment.work_kind?("time_3_8")
  end

  test "time_2_8 is work kind" do
    assert ShiftAssignment.work_kind?("time_2_8")
  end

  test "time_1_8 is work kind" do
    assert ShiftAssignment.work_kind?("time_1_8")
  end

  test "O is not work kind" do
    assert_not ShiftAssignment.work_kind?("O")
  end

  test "nen is not work kind" do
    assert_not ShiftAssignment.work_kind?("nen")
  end

  test "kousei is not work kind" do
    assert_not ShiftAssignment.work_kind?("kousei")
  end

  # ===== off_kind? のテスト =====
  test "O is off kind" do
    assert ShiftAssignment.off_kind?("O")
  end

  test "nen is off kind" do
    assert ShiftAssignment.off_kind?("nen")
  end

  test "kousei is off kind" do
    assert ShiftAssignment.off_kind?("kousei")
  end

  test "D is not off kind" do
    assert_not ShiftAssignment.off_kind?("D")
  end

  test "time_4_8 is not off kind" do
    assert_not ShiftAssignment.off_kind?("time_4_8")
  end

  # ===== calculate_holiday_count のテスト =====
  test "calculate_holiday_count: all D returns 0" do
    kinds = Array.new(20, "D")
    assert_equal 0, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: O counts as 1 holiday" do
    kinds = ["O", "D", "D"]
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: nen counts as 1 holiday" do
    kinds = ["nen", "D"]
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: kousei counts as 1 holiday" do
    kinds = ["kousei", "D"]
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: time_4_8 alone does not count as holiday" do
    kinds = ["time_4_8", "D"]
    assert_equal 0, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: two time_4_8 equals 1 holiday (4+4=8/8)" do
    kinds = ["time_4_8", "time_4_8"]
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: time_4_8 + time_3_8 does not reach 1 holiday (4+3=7/8, truncated)" do
    kinds = ["time_4_8", "time_3_8"]
    assert_equal 0, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: three time_4_8 equals 1 holiday (12/8 = 1, remainder 4/8 truncated)" do
    kinds = ["time_4_8", "time_4_8", "time_4_8"]
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: mixed O and fractions" do
    # O=1日 + time_4_8×2=1日 = 合計2日
    kinds = ["O", "time_4_8", "time_4_8", "D"]
    assert_equal 2, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: time_1_8 × 8 equals 1 holiday" do
    kinds = Array.new(8, "time_1_8")
    assert_equal 1, ShiftAssignment.calculate_holiday_count(kinds)
  end

  test "calculate_holiday_count: time_1_8 × 7 is 0 holidays (truncated)" do
    kinds = Array.new(7, "time_1_8")
    assert_equal 0, ShiftAssignment.calculate_holiday_count(kinds)
  end

  # ===== calculate_special_leave_count のテスト =====
  test "calculate_special_leave_count: nen counts" do
    kinds = ["nen", "D", "D"]
    assert_equal 1, ShiftAssignment.calculate_special_leave_count(kinds)
  end

  test "calculate_special_leave_count: kousei counts" do
    kinds = ["kousei", "D"]
    assert_equal 1, ShiftAssignment.calculate_special_leave_count(kinds)
  end

  test "calculate_special_leave_count: O does not count" do
    kinds = ["O", "D"]
    assert_equal 0, ShiftAssignment.calculate_special_leave_count(kinds)
  end

  test "calculate_special_leave_count: time_4_8 does not count" do
    kinds = ["time_4_8", "D"]
    assert_equal 0, ShiftAssignment.calculate_special_leave_count(kinds)
  end
end
