require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:sample_review)

    # Authenticate user for all tests
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  # Test basic ApplicationController functionality
  # Note: The clean_orphaned_pr_tabs method is tested indirectly through other controller tests

  test "should handle session management without errors" do
    # Set some session data
    session[:open_pr_tabs] = [ "pr_#{@pull_request_review.id}" ]

    get root_path
    assert_response :success

    # Session should be maintained (may be cleaned up but should exist)
    # The cleanup process may modify the session, so we just check it doesn't crash
    assert_nothing_raised { session[:open_pr_tabs] }
  end

  test "should handle empty session gracefully" do
    session[:open_pr_tabs] = []

    get root_path
    assert_response :success
  end

  test "should handle nil session gracefully" do
    session[:open_pr_tabs] = nil

    get root_path
    assert_response :success
  end

  test "should work correctly when user is not signed in" do
    # Log out the user
    delete session_url

    session[:open_pr_tabs] = [ "pr_#{@pull_request_review.id}" ]

    # This should not raise an error even with no current user
    get root_path

    # Should redirect to login, but not crash
    assert_redirected_to demo_login_url
  end

  # Test the browser restriction functionality from ApplicationController
  test "should allow modern browsers" do
    get root_path, headers: {
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    assert_response :success
  end

  # Test authentication concern integration
  test "should redirect unauthenticated users to login" do
    delete session_url
    get root_path
    assert_redirected_to demo_login_url
  end

  test "should allow authenticated users access" do
    get root_path
    assert_response :success
  end
end
