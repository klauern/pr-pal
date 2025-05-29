require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "should get settings index when authenticated" do
    get settings_url
    assert_response :success
    assert_select "h1", "Settings"
  end

  test "should redirect to login when not authenticated" do
    delete session_url
    get settings_url
    assert_redirected_to demo_login_url
  end

  test "should update github token" do
    patch settings_url, params: { user: { github_token: "ghp_test_token_123" } }
    assert_redirected_to settings_url
    assert_equal "Settings updated successfully!", flash[:notice]
    @user.reload
    assert @user.github_token_configured?
  end
end
