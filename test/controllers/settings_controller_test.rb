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
    patch settings_url, params: { user: { form_type: "github", github_token: "ghp_test_token_123" } }
    assert_redirected_to settings_url
    assert_equal "GitHub token updated successfully!", flash[:notice]
    @user.reload
    assert @user.github_token_configured?
  end

  test "should update email address" do
    new_email = "newemail@example.com"
    patch settings_url, params: { user: { form_type: "profile", email_address: new_email } }
    assert_redirected_to settings_url
    assert_equal "Profile updated successfully!", flash[:notice]
    @user.reload
    assert_equal new_email, @user.email_address
  end

  test "should update password" do
    new_password = "newpassword123"
    patch settings_url, params: {
      user: {
        form_type: "password",
        password: new_password,
        password_confirmation: new_password
      }
    }
    assert_redirected_to settings_url
    assert_equal "Password updated successfully!", flash[:notice]

    # Test that the new password works
    delete session_url
    post session_url, params: { email_address: @user.email_address, password: new_password }
    assert_redirected_to root_path
  end

  test "should not update with mismatched password confirmation" do
    patch settings_url, params: {
      user: {
        form_type: "password",
        password: "newpassword123",
        password_confirmation: "different123"
      }
    }
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should not update with invalid email" do
    patch settings_url, params: { user: { form_type: "profile", email_address: "invalid-email" } }
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should handle blank password properly" do
    patch settings_url, params: {
      user: {
        form_type: "password",
        password: "",
        password_confirmation: ""
      }
    }
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should show user profile section" do
    get settings_url
    assert_response :success
    assert_select "h2", "User Profile"
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "should show github integration section" do
    get settings_url
    assert_response :success
    assert_select "h2", "GitHub Integration"
    assert_select "input[name='user[github_token]']"
  end

  test "should show data provider section" do
    get settings_url
    assert_response :success
    assert_select "h2", "Data Provider"
  end

  test "should show separate form sections" do
    get settings_url
    assert_response :success
    assert_select "h2", "User Profile"
    assert_select "h2", "Change Password"
    assert_select "h2", "GitHub Integration"
    assert_select "input[name='user[form_type]'][value='profile']"
    assert_select "input[name='user[form_type]'][value='password']"
    assert_select "input[name='user[form_type]'][value='github']"
  end

  test "should use password field for github token" do
    get settings_url
    assert_response :success
    assert_select "input[name='user[github_token]'][type='password']"
  end

  test "should handle invalid form type" do
    patch settings_url, params: { user: { form_type: "invalid" } }
    assert_redirected_to settings_url
    assert_equal "Invalid form submission.", flash[:alert]
  end
end
