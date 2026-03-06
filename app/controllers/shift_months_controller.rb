require "csv"

class ShiftMonthsController < ApplicationController
  before_action :require_admin, only: [:new, :create, :destroy, :generate]

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

    # 確定済みシフトは非アクティブスタッフも表示する（割当が存在するスタッフを含む）
    # 未確定の場合はアクティブなスタッフのみ
    if @shift_month.is_confirmed
      # 割当が存在するスタッフID（非アクティブを含む）とアクティブスタッフを合わせて表示
      staff_ids_with_assignment = ShiftAssignment
                                    .where(shift_month_id: @shift_month.id)
                                    .distinct
                                    .pluck(:staff_id)
      @staffs = Staff.where("active = ? OR id IN (?)", true, staff_ids_with_assignment.presence || [0])
                     .order(:id)
    else
      @staffs = Staff.where(active: true).order(:id)
    end

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

    @assignment = ShiftAssignment.find_or_initialize_by(
      shift_month_id: @shift_month.id,
      staff_id: staff_id,
      date: date
    )

    if params[:kind].present?
      @assignment.kind = params[:kind]
    else
      @assignment.kind = (@assignment.kind == "D" ? "O" : "D")
    end

    @assignment.save!

    start_date = Date.new(@shift_month.year, @shift_month.month, 1)
    @dates = (start_date..start_date.end_of_month).to_a

    # 集計行更新用に全割当を再取得
    assignments = ShiftAssignment.where(shift_month_id: @shift_month.id)
    @assignment_map = Hash.new { |h, k| h[k] = {} }
    assignments.each { |a| @assignment_map[a.staff_id][a.date] = a }

    # showアクションと同じスタッフ取得ロジック
    if @shift_month.is_confirmed
      staff_ids_with_assignment = assignments.map(&:staff_id).uniq
      @staffs = Staff.where("active = ? OR id IN (?)", true, staff_ids_with_assignment.presence || [0]).order(:id)
    else
      @staffs = Staff.where(active: true).order(:id)
    end

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

    # 確定済みは非アクティブスタッフも含む
    staffs = staffs_for_shift_month(shift_month)
    start_date = Date.new(shift_month.year, shift_month.month, 1)
    dates = (start_date..start_date.end_of_month).to_a

    assignments = ShiftAssignment.where(shift_month_id: shift_month.id)
    assignment_map = Hash.new { |h, k| h[k] = {} }

    assignments.each do |a|
      assignment_map[a.staff_id][a.date] = a.kind
    end

    csv = CSV.generate(force_quotes: true) do |out|
      header = ["名前"] + dates.map { |d| d.day.to_s } + ["休日合計", "年休・厚休"]
      out << header

      staffs.each do |staff|
        row = [staff.name]
        kinds = dates.map { |date| assignment_map.dig(staff.id, date) || "D" }

        kinds.each do |kind|
          row << ShiftAssignment::HUMAN_KINDS[kind]
        end

        row << ShiftAssignment.calculate_holiday_count(kinds)
        row << ShiftAssignment.calculate_special_leave_count(kinds)
        out << row
      end

      # 集計行：出勤人数（D + 分数休暇は出勤扱い）
      work_row = ["出勤人数"] + dates.map { |date|
        assignment_map.values.count { |by_date| ShiftAssignment.work_kind?(by_date[date] || "D") }
      } + ["", ""]
      out << work_row

      # 集計行：休み人数（O, nen, kousei のみ。分数休暇は出勤扱い）
      off_row = ["休み人数"] + dates.map { |date|
        assignment_map.values.count { |by_date| ShiftAssignment.off_kind?(by_date[date] || "D") }
      } + ["", ""]
      out << off_row
    end

    filename = "shift_#{shift_month.year}_#{format('%02d', shift_month.month)}.csv"
    bom = "\uFEFF"
    send_data bom + csv, filename: filename, type: "text/csv; charset=utf-8"
  end

  def export_pdf
    shift_month = ShiftMonth.find(params[:id])

    # 確定済みは非アクティブスタッフも含む
    staffs = staffs_for_shift_month(shift_month)
    start_date = Date.new(shift_month.year, shift_month.month, 1)
    dates = (start_date..start_date.end_of_month).to_a

    assignments = ShiftAssignment.where(shift_month_id: shift_month.id)
    assignment_map = Hash.new { |h, k| h[k] = {} }

    assignments.each do |a|
      assignment_map[a.staff_id][a.date] = a.kind
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
    header = ["名前"] + dates.map { |d| d.day.to_s } + ["休日合計", "年休・厚休"]
    table_data = [header]

    staffs.each do |staff|
      row = [staff.name]
      kinds = dates.map { |date| assignment_map.dig(staff.id, date) || "D" }

      kinds.each do |kind|
        row << ShiftAssignment::HUMAN_KINDS[kind]
      end

      row << ShiftAssignment.calculate_holiday_count(kinds)
      row << ShiftAssignment.calculate_special_leave_count(kinds)
      table_data << row
    end

    # 集計行：出勤人数（D + 分数休暇は出勤扱い）
    work_row = ["出勤人数"] + dates.map { |date|
      assignment_map.values.count { |by_date| ShiftAssignment.work_kind?(by_date[date] || "D") }
    } + ["", ""]
    table_data << work_row

    # 集計行：休み人数（O, nen, kousei のみ）
    off_row = ["休み人数"] + dates.map { |date|
      assignment_map.values.count { |by_date| ShiftAssignment.off_kind?(by_date[date] || "D") }
    } + ["", ""]
    table_data << off_row

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

      row(-2..-1).background_color = "F8F9FA"
      row(-2..-1).font_style = :bold

      dates.each_with_index do |date, i|
        col_index = i + 1
        if date.sunday?
          columns(col_index).background_color = "FFECEC"
        elsif date.saturday?
          columns(col_index).background_color = "EEF4FF"
        elsif HolidayJapan.check(date)
          columns(col_index).background_color = "FFF2CC"
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

  # 確定済みシフトは非アクティブスタッフも含む、未確定はアクティブのみ
  def staffs_for_shift_month(shift_month)
    if shift_month.is_confirmed
      staff_ids_with_assignment = ShiftAssignment
                                    .where(shift_month_id: shift_month.id)
                                    .distinct
                                    .pluck(:staff_id)
      Staff.where("active = ? OR id IN (?)", true, staff_ids_with_assignment.presence || [0]).order(:id)
    else
      Staff.where(active: true).order(:id)
    end
  end

  def shift_month_params
    params.require(:shift_month).permit(
      :year,
      :month,
      :required_day_shifts_weekday,
      :required_day_shifts_sun_holiday,
      :max_consecutive_work_days,
      :required_day_shifts,
      :request_deadline
    )
  end
end
