class ShiftGenerator
  DAY_SHIFT = "D"
  OFF       = "O"

  def initialize(shift_month:)
    @shift_month = shift_month
  end

  def call!
    ActiveRecord::Base.transaction do
      staff_ids = Staff.where(active: true).order(:id).pluck(:id)
      dates     = month_dates(@shift_month.year, @shift_month.month)

      # 希望休（必須）
      requested_off = ShiftRequest
                        .where(shift_month_id: @shift_month.id, kind: "off")
                        .pluck(:date, :staff_id)
                        .each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(date, staff_id), h|
                          h[date] << staff_id
                        end

      # まず不可能判定（早期に落とす）
      shortages = compute_shortages(staff_ids:, dates:, requested_off:)
      if shortages.any?
        raise NoSolutionError.new(
          "シフトを作成できませんでした（最適解なし）",
          shortages: shortages
        )
      end

      # 既存の割当を消して作り直し（同じ月を再生成できるように）
      ShiftAssignment.where(shift_month_id: @shift_month.id).delete_all

      required = @shift_month.required_day_shifts
      d_counts = Hash.new(0) # staff_id => D回数

      dates.each do |date|
        off_ids = requested_off[date] || Set.new
        available_ids = staff_ids - off_ids.to_a

        # 公平性：D回数が少ない順に必要人数を割り当て
        day_workers = available_ids.sort_by { |sid| d_counts[sid] }.take(required)

        # D を割り当て
        day_workers.each do |sid|
          ShiftAssignment.create!(
            staff_id: sid,
            shift_month_id: @shift_month.id,
            date: date,
            kind: DAY_SHIFT
          )
          d_counts[sid] += 1
        end

        # 残りは O（希望休も含む）
        off_targets = staff_ids - day_workers
        off_targets.each do |sid|
          ShiftAssignment.create!(
            staff_id: sid,
            shift_month_id: @shift_month.id,
            date: date,
            kind: OFF
          )
        end
      end

      @shift_month.update!(status: "generated")
    end

    true
  end

  private

  def month_dates(year, month)
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    (start_date..end_date).to_a
  end

  def compute_shortages(staff_ids:, dates:, requested_off:)
    required = @shift_month.required_day_shifts

    dates.filter_map do |date|
      off_ids = requested_off[date] || Set.new
      available = staff_ids.size - off_ids.size
      next if available >= required

      {
        date: date,
        required: required,
        available: available,
        shortage: required - available
      }
    end
  end
end
