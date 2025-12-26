require "csv"

class ShiftMonthsController < ApplicationController
  def new
    @shift_month = ShiftMonth.new
  end

  def create
    @shift_month = ShiftMonth.new(shift_month_params.merge(status: "draft"))
    if @shift_month.save
      redirect_to @shift_month
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @shift_month = ShiftMonth.find(params[:id])
    @error_message = flash[:error_message]
    @shortages     = flash[:shortages] || []
    @shift_request = ShiftRequest.new
    @staffs        = Staff.where(active: true).order(:id)

    @requests = ShiftRequest
                  .includes(:staff)
                  .where(shift_month_id: @shift_month.id, kind: "off")
                  .order(:date, :staff_id)

    @requested_off_map = Hash.new { |h, k| h[k] = {} }
    @requests.each do |r|
      @requested_off_map[r.staff_id][r.date] = true
    end

    start_date = Date.new(@shift_month.year, @shift_month.month, 1)
    end_date   = start_date.end_of_month
    @dates     = (start_date..end_date).to_a

    assignments = ShiftAssignment
                    .where(shift_month_id: @shift_month.id)
                    .order(:date, :staff_id)

    @assignment_map = Hash.new { |h, k| h[k] = {} }
    assignments.each do |a|
      @assignment_map[a.staff_id][a.date] = a
    end
  end

  def generate
    shift_month = ShiftMonth.find(params[:id])

    begin
      ShiftGenerator.new(shift_month: shift_month).call!
      redirect_to shift_month, notice: "シフトを生成しました"
    rescue NoSolutionError => e
      flash[:error_message] = e.message
      # flashはシリアライズされるのでDateは文字列にしておく
      flash[:shortages] = e.shortages.map do |h|
        h.merge(date: h[:date].to_s)
      end
      redirect_to shift_month
    end
  end

  def toggle_assignment
    @shift_month = ShiftMonth.find(params[:id])

    staff_id = params.require(:staff_id).to_i
    date     = Date.parse(params.require(:date))

    @staff = Staff.find(staff_id)
    @date  = date

    @assignment = ShiftAssignment.find_or_create_by!(
      shift_month_id: @shift_month.id,
      staff_id: staff_id,
      date: date
    ) do |a|
      a.kind = "D"
    end

    @assignment.kind = (@assignment.kind == "D" ? "O" : "D")
    @assignment.save!

    start_date = Date.new(@shift_month.year, @shift_month.month, 1)
    @dates = (start_date..start_date.end_of_month).to_a

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @shift_month, notice: "勤務を更新しました" }
    end
  end

  def export_csv
    shift_month = ShiftMonth.find(params[:id])

    staffs = Staff.where(active: true).order(:id)
    start_date = Date.new(shift_month.year, shift_month.month, 1)
    dates = (start_date..start_date.end_of_month).to_a

    assignments = ShiftAssignment.where(shift_month_id: shift_month.id)
    assignment_map = Hash.new { |h, k| h[k] = {} }
    assignments.each { |a| assignment_map[a.staff_id][a.date] = a.kind }

    csv = CSV.generate(force_quotes: true) do |out|
      # ヘッダ：名前 + 日付(曜日)
      header = ["名前"] + dates.map { |d| "#{d.strftime('%Y-%m-%d')} (#{%w(日 月 火 水 木 金 土)[d.wday]})" }
      out << header

      staffs.each do |staff|
        row = [staff.name]
        dates.each do |date|
          kind = assignment_map.dig(staff.id, date) || "D"
          # 表示ルール：休みのみ「休」、出勤は空欄
          row << (kind == "O" ? "休" : "")
        end
        out << row
      end
    end

    filename = "shift_#{shift_month.year}_#{format('%02d', shift_month.month)}.csv"
    bom = "\uFEFF"
    send_data bom + csv, filename: filename, type: "text/csv; charset=utf-8"
  end

  def export_pdf
    shift_month = ShiftMonth.find(params[:id])

    staffs = Staff.where(active: true).order(:id)
    start_date = Date.new(shift_month.year, shift_month.month, 1)
    dates = (start_date..start_date.end_of_month).to_a

    assignments = ShiftAssignment.where(shift_month_id: shift_month.id)
    assignment_map = Hash.new { |h, k| h[k] = {} }
    assignments.each { |a| assignment_map[a.staff_id][a.date] = a.kind }

    pdf = Prawn::Document.new(page_layout: :landscape, margin: 20)

    # === フォント設定（Noto Sans JP） ===
    regular = Rails.root.join("app/assets/fonts/NotoSansJP-Regular.ttf")
    bold    = Rails.root.join("app/assets/fonts/NotoSansJP-Bold.ttf")

    unless File.exist?(regular)
      raise "Noto Sans JP font not found. app/assets/fonts に配置してください"
    end

    pdf.font_families.update(
      "NotoSansJP" => {
        normal: regular.to_s,
        bold:   (File.exist?(bold) ? bold.to_s : regular.to_s)
      }
    )
    pdf.font("NotoSansJP")

    # === タイトル ===
    pdf.text "#{shift_month.year}年#{shift_month.month}月 シフト表",
             size: 16, style: :bold
    pdf.move_down 10

    # === テーブル作成 ===
    wdays = %w(日 月 火 水 木 金 土)
    header = ["名前"] + dates.map { |d| "#{d.day}\n#{wdays[d.wday]}" }

    table_data = [header]
    staffs.each do |staff|
      row = [staff.name]
      dates.each do |date|
        kind = assignment_map.dig(staff.id, date) || "D"
        row << (kind == "O" ? "休" : "")
      end
      table_data << row
    end

    pdf.table(
      table_data,
      header: true,
      cell_style: {
        size: 9,
        align: :center,
        valign: :center,
        padding: [3, 3, 3, 3]
      }
    ) do
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      columns(0).align = :left
      columns(0).width = 90
    end

    filename = "shift_#{shift_month.year}_#{format('%02d', shift_month.month)}.pdf"
    send_data pdf.render,
              filename: filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def shift_month_params
    params.require(:shift_month).permit(:year, :month, :required_day_shifts)
  end
end
