require "test_helper"

class ShiftGeneratorTest < ActiveSupport::TestCase
  def setup
    # リーダースタッフ1名 + 一般スタッフ4名（計5名）
    @leader = Staff.create!(
      name: "リーダー",
      email: "leader@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: true,
      active: true
    )
    @staff1 = Staff.create!(
      name: "スタッフ1",
      email: "staff1@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: false,
      active: true
    )
    @staff2 = Staff.create!(
      name: "スタッフ2",
      email: "staff2@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: false,
      active: true
    )
    @staff3 = Staff.create!(
      name: "スタッフ3",
      email: "staff3@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: false,
      active: true
    )
    @staff4 = Staff.create!(
      name: "スタッフ4",
      email: "staff4@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: false,
      active: true
    )
    # リーダー2名目（連勤上限5日を超えないために2名必要）
    @leader2 = Staff.create!(
      name: "リーダー2",
      email: "leader2@test.com",
      password: "password",
      password_confirmation: "password",
      is_leader: true,
      active: true
    )

    # 2026年4月（30日間）のシフト月
    # 平日必要人数: 2名, 日祝必要人数: 1名, 連勤上限: 5日
    @shift_month = ShiftMonth.create!(
      year: 2026,
      month: 4,
      required_day_shifts: 10,
      max_consecutive_work_days: 5,
      required_day_shifts_weekday: 2,
      required_day_shifts_sun_holiday: 1
    )
  end

  # =========================================================================
  # 正常系テスト
  # =========================================================================

  test "リーダーが1名以上いる場合にシフトを生成できる" do
    generator = ShiftGenerator.new(shift_month: @shift_month)
    assert generator.call!
    assert_equal "generated", @shift_month.reload.status
  end

  test "シフト生成後にShiftAssignmentが作成される" do
    generator = ShiftGenerator.new(shift_month: @shift_month)
    generator.call!
    dates = (Date.new(2026, 4, 1)..Date.new(2026, 4, 30)).to_a
    staff_count = Staff.where(active: true).count
    # 全スタッフ × 全日数分のレコードが作成されるはず
    assert_equal staff_count * dates.size, ShiftAssignment.where(shift_month_id: @shift_month.id).count
  end

  test "各日の出勤人数が必要人数以上になる" do
    generator = ShiftGenerator.new(shift_month: @shift_month)
    generator.call!
    dates = (Date.new(2026, 4, 1)..Date.new(2026, 4, 30)).to_a
    dates.each do |date|
      required = @shift_month.required_for(date)
      actual = ShiftAssignment.where(
        shift_month_id: @shift_month.id,
        date: date,
        kind: "D"
      ).count
      assert actual >= required,
        "#{date}: 必要人数#{required}名に対して#{actual}名しかいない"
    end
  end

  test "希望休が正しく反映される（希望休の日は出勤にならない）" do
    # リーダーの4/7（火曜）に希望休を設定
    ShiftRequest.create!(
      staff: @leader,
      shift_month: @shift_month,
      date: Date.new(2026, 4, 7),
      kind: "off"
    )
    generator = ShiftGenerator.new(shift_month: @shift_month)
    generator.call!

    assignment = ShiftAssignment.find_by(
      shift_month_id: @shift_month.id,
      staff_id: @leader.id,
      date: Date.new(2026, 4, 7)
    )
    assert_not_nil assignment
    assert_equal "O", assignment.kind, "希望休の日はOになるべき"
  end

  test "各スタッフの連勤日数が上限を超えない" do
    generator = ShiftGenerator.new(shift_month: @shift_month)
    generator.call!

    Staff.where(active: true).each do |staff|
      assignments = ShiftAssignment.where(
        shift_month_id: @shift_month.id,
        staff_id: staff.id
      ).order(:date)

      consecutive = 0
      assignments.each do |a|
        if a.kind == "D"
          consecutive += 1
          assert consecutive <= @shift_month.max_consecutive_work_days,
            "#{staff.name}: 連勤上限#{@shift_month.max_consecutive_work_days}日を超えた（#{consecutive}日連続）"
        else
          consecutive = 0
        end
      end
    end
  end

  test "再生成すると既存のシフット割当が上書きされる" do
    generator = ShiftGenerator.new(shift_month: @shift_month)
    generator.call!
    first_count = ShiftAssignment.where(shift_month_id: @shift_month.id).count

    # 再生成
    generator.call!
    second_count = ShiftAssignment.where(shift_month_id: @shift_month.id).count

    # 件数は同じはず（delete_allして再生成）
    assert_equal first_count, second_count
  end

  # =========================================================================
  # 異常系テスト
  # =========================================================================

  test "リーダーが0名の場合にNoSolutionErrorが発生する" do
    @leader.update!(is_leader: false)
    generator = ShiftGenerator.new(shift_month: @shift_month)
    assert_raises(NoSolutionError) do
      generator.call!
    end
  end

  test "総労働力が不足する場合にNoSolutionErrorが発生する" do
    # 必要人数を非常に大きくする（スタッフ5名では不可能な設定）
    @shift_month.update!(
      required_day_shifts_weekday: 10,
      required_day_shifts_sun_holiday: 10
    )
    generator = ShiftGenerator.new(shift_month: @shift_month)
    assert_raises(NoSolutionError) do
      generator.call!
    end
  end

  test "希望休過多で人手不足の場合にNoSolutionErrorが発生する" do
    # 4/1（水曜）に全スタッフが希望休（必要人数2名に対して候補0名）
    Staff.where(active: true).each do |staff|
      ShiftRequest.create!(
        staff: staff,
        shift_month: @shift_month,
        date: Date.new(2026, 4, 1),
        kind: "off"
      )
    end
    generator = ShiftGenerator.new(shift_month: @shift_month)
    assert_raises(NoSolutionError) do
      generator.call!
    end
  end

  test "NoSolutionErrorにshortages情報が含まれる" do
    @leader.update!(is_leader: false)
    generator = ShiftGenerator.new(shift_month: @shift_month)
    error = assert_raises(NoSolutionError) do
      generator.call!
    end
    assert_not_nil error.shortages
    assert error.shortages.any?
  end
end
