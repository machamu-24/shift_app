require "test_helper"

class ShiftMonthsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # 管理者スタッフを作成
    @admin = Staff.create!(
      name: "管理者テスト",
      email: "admin_test@example.com",
      password: "password",
      password_confirmation: "password",
      role: :admin,
      is_leader: true,
      active: true
    )
    # 一般スタッフを作成
    @general = Staff.create!(
      name: "一般テスト",
      email: "general_test@example.com",
      password: "password",
      password_confirmation: "password",
      role: :general,
      active: true
    )
    # テスト用シフト月を作成
    @shift_month = ShiftMonth.create!(
      year: 2026,
      month: 4,
      required_day_shifts: 10,
      max_consecutive_work_days: 5,
      required_day_shifts_weekday: 5,
      required_day_shifts_sun_holiday: 3
    )
  end

  # =========================================================================
  # 認証テスト
  # =========================================================================

  test "未ログイン状態でシフト一覧にアクセスするとログインページにリダイレクトされる" do
    get shift_months_path
    assert_redirected_to login_path
  end

  test "未ログイン状態でシフト詳細にアクセスするとログインページにリダイレクトされる" do
    get shift_month_path(@shift_month)
    assert_redirected_to login_path
  end

  test "未ログイン状態でシフト新規作成にアクセスするとログインページにリダイレクトされる" do
    get new_shift_month_path
    assert_redirected_to login_path
  end

  # =========================================================================
  # 認可テスト（一般ユーザーは管理者専用機能にアクセスできない）
  # =========================================================================

  test "一般ユーザーがシフト新規作成ページにアクセスするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    get new_shift_month_path
    assert_redirected_to root_path
  end

  test "一般ユーザーがシフト月を作成しようとするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    post shift_months_path, params: {
      shift_month: {
        year: 2026, month: 5,
        required_day_shifts: 10,
        max_consecutive_work_days: 5,
        required_day_shifts_weekday: 5,
        required_day_shifts_sun_holiday: 3
      }
    }
    assert_redirected_to root_path
  end

  test "一般ユーザーがシフト月を削除しようとするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    delete shift_month_path(@shift_month)
    assert_redirected_to root_path
  end

  test "一般ユーザーがシフト自動生成を実行しようとするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    post generate_shift_month_path(@shift_month)
    assert_redirected_to root_path
  end

  # =========================================================================
  # 管理者機能テスト
  # =========================================================================

  test "管理者がシフト一覧を表示できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    get shift_months_path
    assert_response :success
  end

  test "管理者がシフト詳細を表示できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    get shift_month_path(@shift_month)
    assert_response :success
  end

  test "管理者がシフト月を新規作成できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_difference "ShiftMonth.count", 1 do
      post shift_months_path, params: {
        shift_month: {
          year: 2026, month: 6,
          required_day_shifts: 10,
          max_consecutive_work_days: 5,
          required_day_shifts_weekday: 5,
          required_day_shifts_sun_holiday: 3
        }
      }
    end
    assert_redirected_to shift_month_path(ShiftMonth.last)
  end

  test "同一年月のシフト月を重複作成すると既存シフトにリダイレクトされる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_no_difference "ShiftMonth.count" do
      post shift_months_path, params: {
        shift_month: {
          year: @shift_month.year, month: @shift_month.month,
          required_day_shifts: 10,
          max_consecutive_work_days: 5,
          required_day_shifts_weekday: 5,
          required_day_shifts_sun_holiday: 3
        }
      }
    end
    # 仕様: 重複作成時は422ではなく既存シフト月にリダイレクト（notice付き）
    assert_redirected_to shift_month_path(@shift_month)
    assert_equal "既に作成済みのシフトがあります。", flash[:notice]
  end

  test "管理者がシフト月を削除できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_difference "ShiftMonth.count", -1 do
      delete shift_month_path(@shift_month)
    end
    assert_redirected_to shift_months_path
  end

  # =========================================================================
  # シフト確定テスト
  # =========================================================================

  test "管理者がシフトを確定できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_not @shift_month.is_confirmed
    patch confirm_shift_month_path(@shift_month)
    @shift_month.reload
    assert @shift_month.is_confirmed
    assert_redirected_to shift_month_path(@shift_month)
  end

  test "管理者がシフトの確定を解除できる" do
    @shift_month.update!(is_confirmed: true)
    post login_path, params: { email: @admin.email, password: "password" }
    patch confirm_shift_month_path(@shift_month)
    @shift_month.reload
    assert_not @shift_month.is_confirmed
  end

  # =========================================================================
  # 一般ユーザーのシフト閲覧テスト
  # =========================================================================

  test "一般ユーザーがシフト詳細を閲覧できる" do
    post login_path, params: { email: @general.email, password: "password" }
    get shift_month_path(@shift_month)
    assert_response :success
  end

  test "一般ユーザーがシフト一覧を閲覧できる" do
    post login_path, params: { email: @general.email, password: "password" }
    get shift_months_path
    assert_response :success
  end
end
