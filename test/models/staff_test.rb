require "test_helper"

class StaffTest < ActiveSupport::TestCase
  def setup
    @staff = Staff.new(name: "Test User", email: "test@example.com", password: "password", password_confirmation: "password")
  end

  test "should be valid" do
    assert @staff.valid?
  end

  test "name should be present" do
    @staff.name = "   "
    assert_not @staff.valid?
  end

  test "email should be present" do
    @staff.email = "   "
    assert_not @staff.valid?
  end

  test "email should be unique" do
    duplicate_staff = @staff.dup
    duplicate_staff.email = @staff.email.upcase
    @staff.save
    assert_not duplicate_staff.valid?
  end

  test "password should be present (non-blank)" do
    @staff.password = @staff.password_confirmation = " " * 6
    assert_not @staff.valid?
  end

  test "role should default to general" do
    assert @staff.general?
    assert_equal "general", @staff.role
  end

  test "role can be set to admin" do
    @staff.role = :admin
    assert @staff.admin?
    assert_equal "admin", @staff.role
  end
end
