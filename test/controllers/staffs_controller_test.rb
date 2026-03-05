require "test_helper"

class StaffsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Staff.create!(
      name: "管理者テスト",
      email: "admin_ctrl_test@example.com",
      password: "password",
      password_confirmation: "password",
      role: :admin,
      active: true
    )
    @general = Staff.create!(
      name: "一般テスト",
      email: "general_ctrl_test@example.com",
      password: "password",
      password_confirmation: "password",
      role: :general,
      active: true
    )
  end

  # 認証・認可テスト
  test "未ログイン状態でスタッフ一覧にアクセスするとログインページにリダイレクトされる" do
    get staffs_path
    assert_redirected_to login_path
  end

  test "一般ユーザーがスタッフ一覧にアクセスするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    get staffs_path
    assert_redirected_to root_path
  end

  test "一般ユーザーがスタッフ新規作成ページにアクセスするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    get new_staff_path
    assert_redirected_to root_path
  end

  test "一般ユーザーがスタッフ編集ページにアクセスするとルートにリダイレクトされる" do
    post login_path, params: { email: @general.email, password: "password" }
    get edit_staff_path(@admin)
    assert_redirected_to root_path
  end

  # 管理者機能テスト
  test "管理者がスタッフ一覧を表示できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    get staffs_path
    assert_response :success
  end

  test "管理者がスタッフを新規作成できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_difference "Staff.count", 1 do
      post staffs_path, params: {
        staff: {
          name: "新規スタッフ",
          email: "new_staff@example.com",
          password: "password",
          password_confirmation: "password",
          role: :general,
          active: true,
          is_leader: false
        }
      }
    end
  end

  test "管理者が名前なしでスタッフを作成するとエラーになる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_no_difference "Staff.count" do
      post staffs_path, params: {
        staff: {
          name: "",
          email: "no_name@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "管理者が重複メールアドレスでスタッフを作成するとエラーになる" do
    post login_path, params: { email: @admin.email, password: "password" }
    assert_no_difference "Staff.count" do
      post staffs_path, params: {
        staff: {
          name: "重複テスト",
          email: @admin.email,
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "管理者がスタッフ情報を更新できる" do
    post login_path, params: { email: @admin.email, password: "password" }
    patch staff_path(@general), params: {
      staff: {
        name: "更新後の名前",
        is_leader: true
      }
    }
    @general.reload
    assert_equal "更新後の名前", @general.name
    assert @general.is_leader
  end
end
