require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    # Sign in as the first test user
    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to root_url

    # Now try to access the dashboard
    get dashboard_index_url
    assert_response :success
  end
end
