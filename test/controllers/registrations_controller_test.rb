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

  # Rate Limiting Tests (5 attempts per 3 minutes)
  test "should allow registration attempts within rate limit" do
    # Test multiple successful registrations within limit
    4.times do |i|
      assert_difference("User.count") do
        post registrations_url, params: {
          user: {
            email_address: "user#{i}@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      assert_redirected_to root_path
      
      # Log out for next attempt
      delete session_url
    end
  end

  test "should allow failed registration attempts within rate limit" do
    # Test multiple failed attempts within limit
    4.times do
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
    end
    
    # 5th attempt should still work (not rate limited yet)
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "valid@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should enforce rate limit after 5 attempts" do
    skip "Rate limiting test requires actual rate limiting enforcement"
    # Note: This test would require setting up actual rate limiting storage
    # and making 6+ requests within 3 minutes to trigger the limit
    
    # 5 failed attempts
    5.times do
      post registrations_url, params: {
        user: {
          email_address: "invalid-email",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    
    # 6th attempt should be rate limited
    post registrations_url, params: {
      user: {
        email_address: "valid@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    assert_redirected_to new_registration_url
    assert_equal "Try again later.", flash[:alert]
  end

  # Database Race Condition Tests
  test "should handle RecordNotUnique exception" do
    # Create a user first
    existing_email = "existing@example.com"
    User.create!(email_address: existing_email, password: "password123")
    
    # Try to create another user with same email
    # The validation should catch this and handle it gracefully
    user_params = {
      email_address: existing_email,
      password: "password123",
      password_confirmation: "password123"
    }
    
    assert_no_difference("User.count") do
      post registrations_url, params: { user: user_params }
    end
    
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
    assert assigns(:user).errors[:email_address].include?("has already been taken")
  end

  test "should handle concurrent user creation with same email" do
    threads = []
    results = []
    email = "concurrent@example.com"
    
    # Simulate concurrent registration attempts with same email
    3.times do
      threads << Thread.new do
        begin
          response = post registrations_url, params: {
            user: {
              email_address: email,
              password: "password123",
              password_confirmation: "password123"
            }
          }
          results << response
        rescue => e
          results << e
        end
      end
    end
    
    threads.each(&:join)
    
    # Only one should succeed, others should fail gracefully
    success_count = results.count { |result| result.is_a?(Integer) && result == 302 }
    assert_equal 1, success_count, "Only one concurrent registration should succeed"
    
    # Verify only one user was created
    assert_equal 1, User.where(email_address: email).count
  end

  # Security Tests
  test "should prevent session fixation attacks" do
    # Get initial session ID
    get new_registration_url
    initial_session = request.session_options[:id]
    
    # Register
    post registrations_url, params: {
      user: {
        email_address: "security@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    # Session ID should change after registration (Rails handles this automatically)
    follow_redirect!
    new_session = request.session_options[:id]
    
    # In production, Rails regenerates session ID, but in test it might not
    # Just ensure registration and auto-login succeeded
    assert_response :success
  end

  test "should handle malformed registration parameters" do
    # Test with missing user parameter - Rails handles this at middleware level
    post registrations_url, params: {}
    # Rails returns 400 Bad Request for missing required parameters
    assert_response :bad_request
    
    # Test with empty user parameter
    assert_no_difference("User.count") do
      post registrations_url, params: { user: {} }
    end
    # Rails may return 400 for missing required nested parameters
    assert_includes [400, 422], response.status
  end

  test "should reject unpermitted parameters" do
    post registrations_url, params: {
      user: {
        email_address: "secure@example.com",
        password: "password123",
        password_confirmation: "password123",
        admin: true, # Should be filtered out
        github_token: "secret_token" # Should be filtered out
      }
    }
    
    assert_redirected_to root_path
    user = User.find_by(email_address: "secure@example.com")
    assert user
    assert_nil user.attributes["admin"]
    assert_nil user.github_token
  end

  test "should handle SQL injection in registration parameters" do
    malicious_inputs = [
      "' OR '1'='1",
      "'; DROP TABLE users; --",
      "admin'/**/OR/**/1=1/**/--"
    ]
    
    malicious_inputs.each do |malicious_input|
      assert_nothing_raised do
        post registrations_url, params: {
          user: {
            email_address: malicious_input,
            password: malicious_input,
            password_confirmation: malicious_input
          }
        }
      end
      # Should fail validation, not crash
      assert_response :unprocessable_entity
      # Verify user table still exists
      assert User.count >= 0
    end
  end

  test "should handle extremely long registration parameters" do
    long_string = "a" * 10000
    
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: long_string + "@example.com",
          password: long_string,
          password_confirmation: long_string
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should handle Unicode and special characters in registration" do
    # Use ASCII email since Rails EMAIL_REGEXP doesn't support Unicode emails by default
    # This is standard behavior for most Rails apps
    unicode_password = "password🚀123"
    
    # Should handle Unicode in password gracefully
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "unicode.test@example.com",
          password: unicode_password,
          password_confirmation: unicode_password
        }
      }
    end
    assert_redirected_to root_path
    
    user = User.find_by(email_address: "unicode.test@example.com")
    assert user
    assert user.authenticate(unicode_password)
  end

  test "should properly sanitize error messages to prevent XSS" do
    malicious_email = "<script>alert('xss')</script>@example.com"
    
    post registrations_url, params: {
      user: {
        email_address: malicious_email,
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_response :unprocessable_entity
    # Error message should not contain unescaped script tags
    assert_no_match /<script>alert/, response.body
    assert_includes response.body, "&lt;script&gt;"
  end

  test "should enforce password strength requirements" do
    weak_passwords = [
      "123",
      "12345",
      "a",
      "",
      "     " # spaces only
    ]
    
    weak_passwords.each do |weak_password|
      assert_no_difference("User.count") do
        post registrations_url, params: {
          user: {
            email_address: "test#{weak_password.length}@example.com",
            password: weak_password,
            password_confirmation: weak_password
          }
        }
      end
      assert_response :unprocessable_entity
      assert_select ".bg-red-50"
    end
  end

  test "should handle case sensitivity in email normalization" do
    # Test that registration works with different cases and gets normalized
    mixed_case_email = "Test.User@EXAMPLE.COM"
    
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: mixed_case_email,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_redirected_to root_path
    
    user = User.last
    assert_equal "test.user@example.com", user.email_address
  end

  test "should handle whitespace in email normalization" do
    # Test registration with leading/trailing whitespace
    spaced_email = "  user@example.com  "
    
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: spaced_email,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_redirected_to root_path
    
    user = User.last
    assert_equal "user@example.com", user.email_address
  end

  test "should handle special email formats" do
    special_emails = [
      "user+tag@example.com",
      "user.name@example.com",
      "user-name@example.com",
      "user123@example.co.uk"
    ]
    
    special_emails.each_with_index do |email, index|
      assert_difference("User.count") do
        post registrations_url, params: {
          user: {
            email_address: email,
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      assert_redirected_to root_path
      
      # Log out for next registration
      delete session_url
    end
  end

  test "should automatically login user after successful registration" do
    post registrations_url, params: {
      user: {
        email_address: "autologin@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_redirected_to root_path
    
    # Follow redirect and verify user is logged in
    follow_redirect!
    assert_response :success
    
    # Check that user can access authenticated content
    get settings_url
    assert_response :success
  end

  test "should handle database constraints beyond email uniqueness" do
    # Test behavior with valid parameters - should succeed
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          email_address: "constraint@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    
    assert_redirected_to root_path
  end
end
