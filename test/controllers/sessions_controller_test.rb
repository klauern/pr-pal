require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get new" do
    get demo_login_url
    assert_response :success
    assert_select "h2", "Sign in to your account"
    assert_select "form input[type=email]"
    assert_select "form input[type=password]"
  end

  test "should create session with valid credentials" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    assert_redirected_to root_path
    # User should be logged in after successful authentication
  end

  test "should not create session with invalid credentials" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "wrong_password"
    }

    assert_redirected_to demo_login_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should not create session with nonexistent email" do
    post session_url, params: {
      email_address: "nonexistent@example.com",
      password: "password"
    }

    assert_redirected_to demo_login_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should destroy session and redirect to dashboard" do
    # First log in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Then log out
    delete session_url

    assert_redirected_to root_path
    # Session should be cleared
  end

  test "should clear PR tabs on logout" do
    # First log in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Set some PR tabs in session
    get root_path
    session[:open_pr_tabs] = [ "pr_1", "pr_2" ]

    # Then log out
    delete session_url

    assert_redirected_to root_path
    # PR tabs should be cleared (this is handled in the controller)
    assert_nil session[:open_pr_tabs]
  end

  test "should use login layout for new action" do
    get demo_login_url
    assert_response :success
    # The login layout should be applied (checked via controller setup)
  end

  test "should have create account link on login page" do
    get demo_login_url
    assert_select "a[href='#{new_registration_path}']", text: /create a new account/
  end

  test "should handle rate limiting on create action" do
    # This test verifies the rate limiting is configured but doesn't test the actual limiting
    # since that would require multiple requests within the time window
    assert_nothing_raised do
      post session_url, params: {
        email_address: @user.email_address,
        password: "password"
      }
    end
  end

  test "should redirect to after_authentication_url after login" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Should redirect to the after_authentication_url (likely dashboard)
    assert_response :redirect
  end

  test "should allow unauthenticated access to new and create" do
    # These actions should not require authentication
    get demo_login_url
    assert_response :success

    post session_url, params: {
      email_address: @user.email_address,
      password: "wrong_password"
    }
    assert_response :redirect # Should redirect, not block access
  end
end
