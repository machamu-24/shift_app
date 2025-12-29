require "csv"

class ShiftMonthsController < ApplicationController
  before_action :require_admin, only: [:create, :destroy, :generate]

  def new
    @shift_month = ShiftMonth.new(
      required_day_shifts_weekday: 13,
      required_day_shifts_sun_holiday: 5,
      max_consecutive_work_days: 5,
      status: "draft"
    )
    @existing_shift_months = ShiftMonth.order(year: :desc, month: :desc)
  end

  def edit
    @shift_month = ShiftMonth.find(params[:id])
  end

  def index
    @shift_months = ShiftMonth.order(year: :desc, month: :desc)
  end

  def create
    attrs = shift_month_params
    year  = attrs[:year].to_i
    month = attrs[:month].to_i

    if (existing = ShiftMonth.find_by(year: year, month: month))
      redirect_to existing, notice: "既に作成済みのシフトがあります。"
      return
    end

    @shift_month = ShiftMonth.new(attrs.merge(status: "draft"))

    begin
      if @shift_month.save
        redirect_to @shift_month, notice: "シフトを作成しました。"
      else
        flash.now[:alert] = @shift_month.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      existing = ShiftMonth.find_by!(year: year, month: month)
      redirect_to existing, notice: "既に作成済みのシフトがあります。"
    end
  end

  def update
    @shift_month = ShiftMonth.find(params[:id])

    before = @shift_month.slice(
      "max_consecutive_work_days",
      "required_day_shifts_weekday",
      "required_day_shifts_sun_holiday"
    )

    ActiveRecord::Base.transaction do
      if @shift_month.update(shift_month_params)
        after = @shift_month.slice(
          "max_consecutive_work_days",
          "required_day_shifts_weekday",
          "required_day_shifts_sun_holiday"
        )

        settings_changed = (before != after)

        if settings_changed
          ShiftGenerator.new(shift_month: @shift_month).call!
          redirect_to @shift_month, notice: "設定を更新し、シフトを自動で再生成しました。"
        else
          redirect_to @shift_month, notice: "設定を更新しました。"
        end
      else
        flash.now[:alert] = @shift_month.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end
  rescue NoSolutionError => e
    flash.now[:alert] = e.message
    @shortages = e.shortages || []
    render :edit, status: :unprocessable_entity
  end

  def destroy
    shift_month = ShiftMonth.find(params[:id])
    shift_month.destroy
    redirect_to shift_months_path, notice: "#{shift_month.year}年#{shift_month.month}月のシフトデータを削除しました。"
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

    unless current_staff.admin?
      if @shift_month.is_confirmed
        return render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash", locals: { alert: "この月は確定済みのため編集できません。" })
      end
    end

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

  def confirm
    @shift_month = ShiftMonth.find(params[:id])
    if current_staff.admin?
      new_status = !@shift_month.is_confirmed
      @shift_month.update(is_confirmed: new_status)
      flash[:notice] = new_status ? "シフトを確定しました（編集ロック）。" : "シフトの確定を解除しました（編集可能）。"
    else
      flash[:alert] = "権限がありません。"
    end
    redirect_to @shift_month
  end

  def export_csv
    shift_month = ShiftMonth.find(params[:id])

    staffs = Staff.where(active: true).order(:id)
    start_date = Date.new(shift_month.year, shift_month.month, 1)
    dates = (start_date..start_date.end_of_month).to_a

    assignments = ShiftAssignment.where(shift_month_id: shift_month.id)
    assignment_map = Hash.new { |h, k| h[k] = {} }
    
    # 集計用カウンター
    daily_counts = Hash.new { |h, k| h[k] = { "D" => 0, "O" => 0 } }

    assignments.each do |a|
      assignment_map[a.staff_id][a.date] = a.kind
      daily_counts[a.date][a.kind] += 1
    end

    csv = CSV.generate(force_quotes: true) do |out|
      # ヘッダ：名前 + 日付のみ
      header = ["名前"] + dates.map { |d| d.day.to_s }
      out << header

      staffs.each do |staff|
        row = [staff.name]
        dates.each do |date|
          kind = assignment_map.dig(staff.id, date) || "D"
          # 表示ルール：休みのみ「休」、出勤は空欄
          row << (kind == "O" ? "休" : "")
          
          # assignments に D が存在しない場合（ロジック上ありえないが念のため）、空なら D としてカウント
          # (ただし上記の each でカウント済みなので、ここでのカウントは不要。あくまでDBの値を信じる)
        end
        out << row
      end

      # 集計行：出勤人数
      work_counts = ["出勤人数"] + dates.map { |d| daily_counts[d]["D"] }
      out << work_counts

      # 集計行：休み人数
      off_counts = ["休み人数"] + dates.map { |d| daily_counts[d]["O"] }
      out << off_counts
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
    
    daily_counts = Hash.new { |h, k| h[k] = { "D" => 0, "O" => 0 } }
    
    assignments.each do |a|
      assignment_map[a.staff_id][a.date] = a.kind
      daily_counts[a.date][a.kind] += 1
    end

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
    # ヘッダー：日付のみ
    header = ["名前"] + dates.map { |d| d.day.to_s }

    table_data = [header]
    staffs.each do |staff|
      row = [staff.name]
      dates.each do |date|
        kind = assignment_map.dig(staff.id, date) || "D"
        row << (kind == "O" ? "休" : "")
      end
      table_data << row
    end

    # 集計行を追加
    table_data << ["出勤人数"] + dates.map { |d| daily_counts[d]["D"] }
    table_data << ["休み人数"] + dates.map { |d| daily_counts[d]["O"] }

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
      # ヘッダー行スタイル
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      
      # 左端列（名前列）スタイル
      columns(0).align = :left
      columns(0).width = 90
      
      # 集計行スタイル（下2行）
      row(-2..-1).background_color = "F8F9FA"
      row(-2..-1).font_style = :bold

      # 土日祝のカラーリング
      dates.each_with_index do |date, i|
        # テーブル上の列インデックス（名前列が0番目なので +1）
        col_index = i + 1

        if date.sunday?
          columns(col_index).background_color = "FFECEC" # .col-sun
        elsif date.saturday?
          columns(col_index).background_color = "EEF4FF" # .col-sat
        elsif HolidayJapan.check(date)
          columns(col_index).background_color = "FFF2CC" # .col-holiday
        end
      end
    end

    filename = "shift_#{shift_month.year}_#{format('%02d', shift_month.month)}.pdf"
    send_data pdf.render,
              filename: filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def shift_month_params
    params.require(:shift_month).permit(
      :year,
      :month,
      :required_day_shifts_weekday,
      :required_day_shifts_sun_holiday,
      :max_consecutive_work_days,
      :required_day_shifts
    )
  end
end
