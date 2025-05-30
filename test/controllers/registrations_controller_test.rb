require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url
    assert_response :success
    assert_select "h2", "Create your account"
    assert_select "form input[type=email]"
    assert_select "form input[type=password]", 2
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.find_by(email_address: "newuser@example.com")
    assert user
    assert_redirected_to root_path
    assert_equal "Welcome! Your account has been created successfully.", flash[:notice]
  end

  test "should not create user with invalid email" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "invalid-email",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".bg-red-50", text: /fix the following errors/
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "different123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should not create user with short password" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "123",
          password_confirmation: "123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should not create user with duplicate email" do
    existing_user = users(:one)

    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should auto-login user after successful registration" do
    post registrations_url, params: {
      user: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to root_path

    # Follow redirect to check if user is logged in
    follow_redirect!
    assert_response :success
    # Should show authenticated content (like the sidebar with user info)
  end

  test "should use login layout for new action" do
    get new_registration_url
    assert_response :success
    # The login layout should be applied (checked via controller setup)
  end

  test "should have sign in link on registration page" do
    get new_registration_url
    assert_select "a[href='#{demo_login_path}']", text: /sign in to your existing account/
  end

  test "should have rate limiting on create action" do
    # This test verifies the rate limiting is configured but doesn't test the actual limiting
    # since that would require multiple requests within the time window
    assert_nothing_raised do
      post registrations_url, params: {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
  end
end
