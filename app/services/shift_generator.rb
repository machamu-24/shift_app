class ShiftGenerator
  DAY_SHIFT = "D"
  OFF       = "O"
  MAX_CONSECUTIVE_WORK = 5

  def initialize(shift_month:)
    @shift_month = shift_month
  end

  def call!
    ActiveRecord::Base.transaction do
      # staff_ids を取得するが、リーダー情報も必要なので Staff オブジェクトを取得する
      all_staffs = Staff.where(active: true).order(:id)
      staff_ids = all_staffs.pluck(:id)
      leader_ids = all_staffs.select(&:is_leader).map(&:id).to_set

      dates = month_dates(@shift_month.year, @shift_month.month)

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

      # =========================================================================
      # 1. 生成前の不可能判定（総量）
      # =========================================================================
      required_slots = dates.sum { |d| @shift_month.required_for(d) }
      supply_slots   = staff_ids.size * max_work
      if supply_slots < required_slots
        raise NoSolutionError.new(
          "シフトを作成できませんでした（制約上不可能：総労働力不足）",
          shortages: [{
            type: "monthly_capacity",
            required: required_slots,
            available: supply_slots
          }]
        )
      end

      # =========================================================================
      # 2. 生成前の不可能判定（日別：希望休により候補が required 未満の日がある）
      # =========================================================================
      shortages = compute_shortages(staff_ids:, dates:, requested_off:)
      if shortages.any?
        raise NoSolutionError.new(
          "シフトを作成できませんでした（最適解なし：希望休過多）",
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

        # 出勤可能な候補者（基本）
        available_ids = staff_ids - off_ids.to_a
        # 月間最大労働日数を超えた人は除外
        available_ids = available_ids.reject { |sid| d_counts[sid] >= max_work }
        
        # ハード制約：連勤上限
        # 上限に達している人は**絶対に**選ばない
        pool = available_ids.reject { |sid| consec[sid] >= max_consec }

        # -----------------------------------------------------------------------
        # リーダー制約対応
        # poolの中にリーダーがいるか確認し、いなければ優先的にリーダーを確保する必要がある
        # -----------------------------------------------------------------------
        available_leaders = pool.select { |sid| leader_ids.include?(sid) }
        available_members = pool.reject { |sid| leader_ids.include?(sid) }

        # リーダー必須（もし必要人数 > 0 ならリーダーも1人以上必須と仮定）
        need_leader = required > 0
        
        # 決定された勤務者リスト
        picked_workers = []

        if need_leader
          if available_leaders.empty?
            # リーダーが一人も出勤できない -> 解なし
            raise NoSolutionError.new(
              "シフトを作成できませんでした（リーダー不足: #{date}）",
              shortages: [
                { date: date, required: 1, available: 0, shortage: 1 }
              ]
            )
          end

          # スコアリング（優先度計算）
          # 優先度高: 連勤数が少ない > 勤務回数が少ない
          # ソフト制約：なるべく連勤数を少なくする -> straight_days をスコアに含める
          score_func = ->(sid) { [consec[sid], d_counts[sid], sid] }

          # リーダーをまず1名選出（スコア順）
          best_leader = available_leaders.min_by(&score_func)
          picked_workers << best_leader

          # 残りの候補者リストを再構築（選ばれたリーダーを除く）
          min_pool = pool - [best_leader]
        else
          min_pool = pool
        end

        # 残りの必要人数
        remainder = required - picked_workers.size

        if min_pool.size < remainder
           raise NoSolutionError.new(
            "シフトを作成できませんでした（人手不足: #{date}）",
            shortages: [{
              date: date,
              required: required,
              available: pool.size, # 元々のpoolサイズ
              shortage: required - pool.size
            }]
          )
        end

        # 残りのメンバーを選出
        # ソート基準: 連勤数(昇順) -> 勤務回数(昇順)
        sorted_candidates = min_pool.sort_by { |sid| [consec[sid], d_counts[sid], sid] }
        picked_workers.concat(sorted_candidates.take(remainder))

        day_workers = picked_workers

        # -----------------------------------------------------------------------
        # データベース登録用の行を作成
        # -----------------------------------------------------------------------
        
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

        # O を積む（希望休含む、poolから漏れた人も含む）
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

        # -----------------------------------------------------------------------
        # 連勤数カウンターの更新
        # -----------------------------------------------------------------------
        day_workers.each { |sid| consec[sid] += 1 }
        staff_ids.each do |sid|
          next if day_worker_set.include?(sid)
          consec[sid] = 0 # 休みならリセット
        end
      end

      # 一括インサート
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
