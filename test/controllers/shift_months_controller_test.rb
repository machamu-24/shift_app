require "test_helper"

class ShiftMonthsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get shift_months_new_url
    assert_response :success
  end

  test "should get create" do
    get shift_months_create_url
    assert_response :success
  end

  test "should get show" do
    get shift_months_show_url
    assert_response :success
  end
end
