class AddUniqueIndexToShiftMonthsYearMonth < ActiveRecord::Migration[7.1]
  def up
    # 重複データを削除 (SQLベースで実行)
    # アプリケーションのモデル(ShiftMonth等)への依存を回避
    
    # 1. 重複している (year, month) の組み合わせを取得
    duplicates = ActiveRecord::Base.connection.select_all(<<-SQL)
      SELECT year, month
      FROM shift_months
      GROUP BY year, month
      HAVING count(*) > 1
    SQL

    duplicates.each do |dup|
      year = dup['year']
      month = dup['month']

      # 2. 対象の year, month を持つレコードのIDを取得
      #    ORDER BY id ASC なので、最後 (last) が最新として残す
      ids = ActiveRecord::Base.connection.select_values(<<-SQL)
        SELECT id FROM shift_months
        WHERE year = #{year} AND month = #{month}
        ORDER BY id ASC
      SQL

      # 最新(IDが最大)の一つを除外
      keep_id = ids.last
      delete_ids = ids - [keep_id]

      next if delete_ids.empty?

      # 3. 削除対象のIDに関連するデータを削除
      # shift_assignments
      ActiveRecord::Base.connection.execute(<<-SQL)
        DELETE FROM shift_assignments WHERE shift_month_id IN (#{delete_ids.join(',')})
      SQL

      # shift_requests
      ActiveRecord::Base.connection.execute(<<-SQL)
        DELETE FROM shift_requests WHERE shift_month_id IN (#{delete_ids.join(',')})
      SQL

      # 4. shift_months 自体を削除
      ActiveRecord::Base.connection.execute(<<-SQL)
        DELETE FROM shift_months WHERE id IN (#{delete_ids.join(',')})
      SQL
    end

    add_index :shift_months, %i[year month], unique: true, name: "index_shift_months_on_year_and_month_unique"
  end

  def down
    remove_index :shift_months, name: "index_shift_months_on_year_and_month_unique"
  end
end
