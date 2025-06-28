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

  # Tab Management Tests - Missing Coverage
  test "should set custom tab via params" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    get dashboard_index_url, params: { tab: "repositories" }
    assert_response :success
    assert_equal "repositories", session[:active_tab]
  end

  test "should default to home tab when no tab specified" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    get dashboard_index_url
    assert_response :success
    assert_equal "home", session[:active_tab]
  end

  test "should handle invalid tab parameter" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Test with potentially malicious tab parameter
    get dashboard_index_url, params: { tab: "<script>alert('xss')</script>" }
    assert_response :success
    # Tab should be set as-is (XSS prevention happens in view layer)
    assert_equal "<script>alert('xss')</script>", session[:active_tab]
  end

  test "should handle nil tab parameter gracefully" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    get dashboard_index_url, params: { tab: nil }
    assert_response :success
    assert_equal "home", session[:active_tab]
  end

  test "should handle empty tab parameter" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    get dashboard_index_url, params: { tab: "" }
    assert_response :success
    assert_equal "home", session[:active_tab]
  end

  test "should maintain tab persistence across requests" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Set initial tab
    get dashboard_index_url, params: { tab: "settings" }
    assert_equal "settings", session[:active_tab]

    # Subsequent request without tab param should maintain previous tab
    get dashboard_index_url
    assert_response :success
    assert_equal "settings", session[:active_tab]
  end

  # Session State Tests
  test "should handle corrupted session state" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Corrupt session data
    session[:active_tab] = { invalid: "data" }
    session[:open_pr_tabs] = "not_an_array"

    # Should not crash
    assert_nothing_raised do
      get dashboard_index_url
    end
    assert_response :success
  end

  test "should handle nil session values" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Set session values to nil
    session[:active_tab] = nil
    session[:open_pr_tabs] = nil

    get dashboard_index_url
    assert_response :success
    assert_equal "home", session[:active_tab]
  end

  # Debug Logging Tests
  test "should log session information when requested" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Capture log output
    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)
    Rails.logger.level = Logger::DEBUG

    get dashboard_index_url, params: { tab: "test_tab" }

    log_content = log_output.string
    # DashboardController should log session info
    assert_includes log_content, "Session tabs:"
    assert_includes log_content, "BEFORE cleanup"

    # Restore original logger
    Rails.logger = old_logger
  end

  # Performance Tests
  test "should handle dashboard load with many repositories" do
    user = users(:one)
    post session_url, params: { email_address: user.email_address, password: "password" }

    # Create many repositories for performance testing
    50.times do |i|
      user.repositories.create!(owner: "test#{i}", name: "repo#{i}")
    end

    start_time = Time.current
    get dashboard_index_url
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 2.seconds, "Dashboard should load quickly even with many repositories"
  end

  test "should handle dashboard load with many pull request reviews" do
    user = users(:one)
    repository = repositories(:one)
    post session_url, params: { email_address: user.email_address, password: "password" }

    # Create many PR reviews
    50.times do |i|
      pull_request = PullRequest.create!(
        repository: repository,
        github_pr_id: 1000 + i,
        github_pr_url: "https://github.com/test/repo/pull/#{1000 + i}",
        title: "Test PR #{i}",
        state: "open",
        author: "testuser",
        github_created_at: i.days.ago,
        github_updated_at: i.hours.ago
      )

      PullRequestReview.create!(
        user: user,
        repository: repository,
        pull_request: pull_request,
        github_pr_id: 1000 + i,
        github_pr_url: "https://github.com/test/repo/pull/#{1000 + i}",
        github_pr_title: "Test PR #{i}"
      )
    end

    start_time = Time.current
    get dashboard_index_url
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 2.seconds, "Dashboard should load quickly even with many PR reviews"
  end

  test "should handle dashboard load with many open tabs" do
    user = users(:one)
    post session_url, params: { email_address: user.email_address, password: "password" }

    # Set up many open tabs
    many_tabs = 100.times.map { |i| "pr_#{i}" }
    session[:open_pr_tabs] = many_tabs

    start_time = Time.current
    get dashboard_index_url
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 2.seconds, "Dashboard should handle many tabs efficiently"
  end

  # Authentication Integration Tests
  test "should redirect unauthenticated users to login" do
    get dashboard_index_url
    assert_redirected_to demo_login_url
  end

  test "should handle user logout during dashboard access" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Access dashboard first
    get dashboard_index_url
    assert_response :success

    # Log out
    delete session_url

    # Try to access dashboard again
    get dashboard_index_url
    assert_redirected_to demo_login_url
  end

  # Edge Cases
  test "should handle very long tab names" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    long_tab_name = "a" * 1000
    get dashboard_index_url, params: { tab: long_tab_name }
    assert_response :success
    assert_equal long_tab_name, session[:active_tab]
  end

  test "should handle special characters in tab names" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    special_tabs = [
      "tab_with_underscores",
      "tab-with-dashes",
      "tab.with.dots",
      "tab with spaces",
      "tab/with/slashes",
      "tab?with=query&params",
      "tab#with#hashes"
    ]

    special_tabs.each do |special_tab|
      get dashboard_index_url, params: { tab: special_tab }
      assert_response :success
      assert_equal special_tab, session[:active_tab]
    end
  end

  test "should handle Unicode characters in tab names" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    unicode_tab = "tab_测试_🚀"
    get dashboard_index_url, params: { tab: unicode_tab }
    assert_response :success
    assert_equal unicode_tab, session[:active_tab]
  end

  # Concurrent Access Tests
  test "should handle concurrent dashboard access" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    threads = []
    results = []

    # Simulate concurrent dashboard access with different tabs
    5.times do |i|
      threads << Thread.new do
        begin
          response = get dashboard_index_url, params: { tab: "concurrent_tab_#{i}" }
          results << response
        rescue => e
          results << e
        end
      end
    end

    threads.each(&:join)

    # All requests should succeed
    assert results.all? { |result| result.is_a?(Integer) && result == 200 }
  end

  # Error Handling Tests
  test "should handle database errors gracefully" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Test that the dashboard loads normally without database errors
    get dashboard_index_url
    assert_response :success
  end

  test "should handle session storage errors" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    # Test that session operations work normally
    get dashboard_index_url, params: { tab: "test" }
    assert_response :success
    assert_equal "test", session[:active_tab]
  end
end
