class AddUniqueIndexToShiftMonthsYearMonth < ActiveRecord::Migration[7.1]
  def up
    # 重複データを削除
    # 同じ年・月のデータが複数ある場合、IDが一番大きい（最新の）ものを残して他を削除します
    duplicates = ShiftMonth.select(:year, :month).group(:year, :month).having("count(*) > 1")

    duplicates.each do |dup|
      records = ShiftMonth.where(year: dup.year, month: dup.month).order(id: :asc).to_a
      keep_record = records.pop # 最後の一つを残す

      records.each do |record|
        # 関連データを削除（依存関係があるため）
        ShiftAssignment.where(shift_month_id: record.id).delete_all
        ShiftRequest.where(shift_month_id: record.id).delete_all
        record.delete
      end
    end

    add_index :shift_months, %i[year month], unique: true, name: "index_shift_months_on_year_and_month_unique"
  end

  def down
    remove_index :shift_months, name: "index_shift_months_on_year_and_month_unique"
  end
end
