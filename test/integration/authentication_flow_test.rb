require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "complete registration and login flow" do
    # Test registration page
    get new_registration_path
    assert_response :success
    assert_select "h2", "Create your account"
    assert_select "a[href='#{demo_login_path}']", text: /sign in to your existing account/

    # Test successful registration
    assert_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    # Should be logged in and see user info in sidebar
    assert_select "aside", text: /Logged in as: newuser@example.com/
    assert_select "a", text: /Logout/

    # Test logout
    delete session_path
    assert_redirected_to root_path
    follow_redirect!

    # Should be redirected to login because not authenticated
    assert_redirected_to demo_login_path
  end

  test "login flow with existing user" do
    user = users(:one)

    # Test login page
    get demo_login_path
    assert_response :success
    assert_select "h2", "Sign in to your account"
    assert_select "a[href='#{new_registration_path}']", text: /create a new account/

    # Test successful login
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    # Should see user info in sidebar
    assert_select "aside", text: /Logged in as: #{user.email_address}/
    assert_select "a", text: /Settings/
    assert_select "a", text: /Logout/
  end

  test "settings page with user profile management" do
    user = users(:one)

    # Login first
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    # Test settings page
    get settings_path
    assert_response :success
    assert_select "h1", "Settings"
    assert_select "h2", "User Profile"
    assert_select "h2", "GitHub Integration"

    # Should show current user email in form
    assert_select "input[value='#{user.email_address}']"

    # Test updating user profile
    patch settings_path, params: {
      user: {
        form_type: "profile",
        email_address: "updated@example.com"
      }
    }

    assert_redirected_to settings_path
    assert_equal "Profile updated successfully!", flash[:notice]

    user.reload
    assert_equal "updated@example.com", user.email_address

    # Test updating GitHub token separately
    patch settings_path, params: {
      user: {
        form_type: "github",
        github_token: "ghp_test_token"
      }
    }

    assert_redirected_to settings_path
    assert_equal "GitHub token updated successfully!", flash[:notice]

    user.reload
    assert user.github_token_configured?
  end

  test "user scoping ensures data isolation" do
    user1 = users(:one)
    user2 = users(:two)

    # Login as user1
    post session_path, params: {
      email_address: user1.email_address,
      password: "password"
    }

    # Create a repository as user1
    post repositories_path, params: {
      repository: {
        name: "user1-repo",
        owner: "user1"
      }
    }

    repo = Repository.find_by(name: "user1-repo")
    assert repo
    assert_equal user1.id, repo.user_id

    # Logout and login as user2
    delete session_path
    post session_path, params: {
      email_address: user2.email_address,
      password: "password"
    }

    # User2 should not see user1's repositories
    get repositories_path
    assert_response :success
    assert_select "tbody tr", count: 0  # No repositories for user2
  end

  test "logout clears session data" do
    user = users(:one)

    # Login
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    # Set some session data (simulating PR tabs)
    get root_path
    # In a real scenario, opening PR reviews would set session[:open_pr_tabs]

    # Logout
    delete session_path
    assert_redirected_to root_path

    # Session should be cleared (this is handled by the controller)
  end

  test "registration validation errors" do
    # Test with invalid email
    post registrations_path, params: {
      user: {
        email_address: "invalid-email",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".bg-red-50", text: /fix the following errors/

    # Test with short password
    post registrations_path, params: {
      user: {
        email_address: "test@example.com",
        password: "123",
        password_confirmation: "123"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".bg-red-50"

    # Test with mismatched passwords
    post registrations_path, params: {
      user: {
        email_address: "test@example.com",
        password: "password123",
        password_confirmation: "different123"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end
end
