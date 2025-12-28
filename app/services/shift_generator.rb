class ShiftGenerator
  DAY_SHIFT = "D"
  OFF       = "O"
  MAX_CONSECUTIVE_WORK = 5

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

      # 最低休日数＝土日祝数（holiday_japan + 土日）
      h = dates.count { |d| d.saturday? || d.sunday? || HolidayJapan.check(d) }
      max_work = dates.size - h

      # 生成前の不可能判定（総量）
      required_slots = dates.sum { |d| @shift_month.required_for(d) }
      supply_slots   = staff_ids.size * max_work
      if supply_slots < required_slots
        raise NoSolutionError.new(
          "シフトを作成できませんでした（制約上不可能）",
          shortages: [{
            type: "monthly_capacity",
            required: required_slots,
            available: supply_slots
          }]
        )
      end

      # まず不可能判定（日別：希望休により候補が required 未満の日がある）
      shortages = compute_shortages(staff_ids:, dates:, requested_off:)
      if shortages.any?
        raise NoSolutionError.new(
          "シフトを作成できませんでした（最適解なし）",
          shortages: shortages
        )
      end

      # 既存の割当を消して作り直し
      ShiftAssignment.where(shift_month_id: @shift_month.id).delete_all

      # 公平性：月内D回数（勤務回数）
      d_counts = Hash.new(0) # staff_id => D回数

      # 連勤数：前日までの連勤数（DB参照しない）
      consec = Hash.new(0)   # staff_id => 直近連勤数

      rows = []
      now  = Time.current

      dates.each do |date|
        required = @shift_month.required_for(date)
        max_consec = @shift_month.max_consecutive_work_days
        off_ids = requested_off[date] # default Set

        available_ids = staff_ids - off_ids.to_a
        available_ids = available_ids.reject { |sid| d_counts[sid] >= max_work }
        eligible_ids  = available_ids.reject { |sid| consec[sid] >= max_consec }

        pool = (eligible_ids.size >= required) ? eligible_ids : available_ids

        # 完全決定論：勤務回数が少ない順 → id順
        day_workers = pool.sort_by { |sid| [d_counts[sid], sid] }.take(required)

        # 必要人数必達（不足なら失敗）
        if day_workers.size < required
          raise NoSolutionError.new(
            "シフトを作成できませんでした（人手不足: #{date}）",
            shortages: [{
              date: date,
              required: required,
              available: day_workers.size,
              shortage: required - day_workers.size
            }]
          )
        end

        # D を積む
        day_workers.each do |sid|
          rows << {
            staff_id: sid,
            shift_month_id: @shift_month.id,
            date: date,
            kind: DAY_SHIFT,
            created_at: now,
            updated_at: now
          }
          d_counts[sid] += 1
        end

        # O を積む（希望休含む）
        day_worker_set = day_workers.to_set
        staff_ids.each do |sid|
          next if day_worker_set.include?(sid)
          rows << {
            staff_id: sid,
            shift_month_id: @shift_month.id,
            date: date,
            kind: OFF,
            created_at: now,
            updated_at: now
          }
        end

        # 連勤数更新
        day_workers.each { |sid| consec[sid] += 1 }
        staff_ids.each do |sid|
          next if day_worker_set.include?(sid)
          consec[sid] = 0
        end
      end

      ShiftAssignment.insert_all!(rows)

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
    dates.filter_map do |date|
      required = @shift_month.required_for(date)
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
