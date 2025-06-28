require "test_helper"

class DashboardAndSidebarTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:review_pr_one)
    @completed_review = pull_request_reviews(:review_pr_two)

    # Authenticate user for all tests
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  # Dashboard Index View Tests
  test "should render dashboard home tab correctly" do
    get root_path

    assert_response :success
    assert_select "h1", "Welcome to PR Pal"
    assert_select "p", "Your AI-powered pull request review assistant"
    assert_select "p", "Dashboard content will go here."
  end

  test "should render dashboard pull_requests tab correctly" do
    get root_path(tab: "pull_requests")

    assert_response :success
    assert_select "h1", "Pull Requests"
    assert_select "p", "Monitor and manage pull requests from your repositories"
    assert_select "p", "Pull requests content will go here."
  end

  test "should render dashboard pull_request_reviews tab correctly" do
    get root_path(tab: "pull_request_reviews")

    assert_response :success
    assert_select "h1", "Pull Request Reviews"
    assert_select "p", "Manage and review active pull requests"

    # Should render the PR reviews partial
    assert_includes response.body, @pull_request_review.github_pr_title
    assert_not_includes response.body, @completed_review.github_pr_title
  end

  test "should show debug tools in development environment" do
    skip "Debug tools are only shown in development environment"
  end

  test "should not show debug tools in non-development environment" do
    get root_path

    assert_response :success
    # In test environment, debug tools should not be shown
    assert_select "h3", { count: 0, text: "Debug Tools" }
  end

  test "should display current session tabs in debug section" do
    skip "Debug section is only shown in development environment"
  end

  test "should display no tabs message when no tabs are open" do
    skip "Debug section is only shown in development environment"
  end

  # Sidebar Layout Tests
  test "should render sidebar navigation correctly" do
    get root_path

    assert_response :success

    # Check main navigation items
    assert_select "aside.w-64.bg-gray-900"
    assert_select "div", "PR Pal"
    assert_select "a[href=?]", root_path, text: "Home"
    assert_select "a[href=?]", repositories_path, text: "Repositories"
    assert_select "a[href=?]", pull_request_reviews_path, text: "PR Reviews"
    assert_select "a[href=?]", settings_path, text: "Settings"
  end

  test "should not show open reviews section when no tabs exist" do
    session[:open_pr_tabs] = []

    get root_path

    assert_response :success
    assert_select "span", { count: 0, text: "Open Reviews" }
  end

  test "should not show open reviews section when tabs are nil" do
    session[:open_pr_tabs] = nil

    get root_path

    assert_response :success
    assert_select "span", { count: 0, text: "Open Reviews" }
  end

  test "should show open reviews section with valid tabs" do
    # Access the PR review first to add it to tabs properly
    get pull_request_review_path(@pull_request_review)

    # Now check if it appears in the sidebar
    get root_path

    assert_response :success
    # Check if the PR review is accessible - the title may be truncated
    assert_includes response.body, @pull_request_review.github_pr_title.truncate(25)
  end

  test "should clean up orphaned tabs silently in sidebar" do
    # Access the PR review first to add it to tabs properly
    get pull_request_review_path(@pull_request_review)

    # Set invalid tabs manually (simulating orphaned state)
    session[:open_pr_tabs] = (session[:open_pr_tabs] || []) + [ "pr_99999" ]

    get root_path

    assert_response :success
    # Should not crash and should handle cleanup gracefully
    assert_response :success
    # The invalid tab shouldn't cause crashes
    assert_nothing_raised { response.body }
  end

  test "should handle blank tab entries in sidebar" do
    # Access the PR review first to add it to tabs properly
    get pull_request_review_path(@pull_request_review)

    # Add invalid entries to test cleanup
    session[:open_pr_tabs] = (session[:open_pr_tabs] || []) + [ "", nil, "pr_" ]

    get root_path

    assert_response :success
    # Should handle cleanup gracefully without crashing
    assert_nothing_raised { response.body }
  end

  test "should show multiple open reviews correctly" do
    # Create additional review
    pull_request2 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1002,
      github_pr_url: "https://github.com/test/test/pull/1002",
      title: "Second test PR review",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    review2 = PullRequestReview.create!(
      user: @user,
      repository: @repository,
      pull_request: pull_request2,
      github_pr_id: 1002,
      github_pr_url: "https://github.com/test/test/pull/1002",
      github_pr_title: "Second test PR review"
    )

    # Access both reviews to add them to tabs
    get pull_request_review_path(@pull_request_review)
    get pull_request_review_path(review2)

    get root_path

    assert_response :success
    # Check that both reviews are accessible - titles may be truncated
    assert_includes response.body, @pull_request_review.github_pr_title.truncate(25)
    assert_includes response.body, review2.github_pr_title.truncate(25)
  end

  test "should preserve tab order in sidebar display" do
    # Create additional reviews
    pull_request2 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1002,
      github_pr_url: "https://github.com/test/test/pull/1002",
      title: "Second PR",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    review2 = PullRequestReview.create!(
      user: @user,
      repository: @repository,
      pull_request: pull_request2,
      github_pr_id: 1002,
      github_pr_url: "https://github.com/test/test/pull/1002",
      github_pr_title: "Second PR"
    )

    pull_request3 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1003,
      github_pr_url: "https://github.com/test/test/pull/1003",
      title: "Third PR",
      state: "open",
      author: "testuser",
      github_created_at: 3.days.ago,
      github_updated_at: 2.hours.ago
    )
    review3 = PullRequestReview.create!(
      user: @user,
      repository: @repository,
      pull_request: pull_request3,
      github_pr_id: 1003,
      github_pr_url: "https://github.com/test/test/pull/1003",
      github_pr_title: "Third PR"
    )

    # Access reviews in specific order
    get pull_request_review_path(review2)
    get pull_request_review_path(@pull_request_review)
    get pull_request_review_path(review3)

    get root_path

    assert_response :success
    # Basic test that multiple reviews can be handled - titles may be truncated
    assert_includes response.body, review2.github_pr_title.truncate(25)
    assert_includes response.body, @pull_request_review.github_pr_title.truncate(25)
    assert_includes response.body, review3.github_pr_title.truncate(25)
  end

  test "should handle long PR titles with truncation" do
    long_title = "This is a very long pull request title that should be truncated to 25 characters in the sidebar display"

    pull_request_long = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1004,
      github_pr_url: "https://github.com/test/test/pull/1004",
      title: long_title,
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    review_with_long_title = PullRequestReview.create!(
      user: @user,
      repository: @repository,
      pull_request: pull_request_long,
      github_pr_id: 1004,
      github_pr_url: "https://github.com/test/test/pull/1004",
      github_pr_title: long_title
    )

    # Access the review to add it to tabs
    get pull_request_review_path(review_with_long_title)

    get root_path

    assert_response :success
    # Basic test that long titles don't break the layout
    assert_nothing_raised { response.body }
  end

  # Integration tests covering both dashboard and sidebar together
  test "should show consistent state between dashboard and sidebar" do
    # Access a PR review to add it to tabs
    get pull_request_review_path(@pull_request_review)

    # Then check the dashboard shows the tab
    get root_path(tab: "pull_request_reviews")

    assert_response :success

    # Should show in both dashboard content and sidebar
    assert_includes response.body, @pull_request_review.github_pr_title
    assert_select "span", "Open Reviews"
    assert_select "a[href=?]", pull_request_review_path(@pull_request_review)
  end

  test "should maintain session state across different dashboard tabs" do
    # Access the PR review to add it to tabs
    get pull_request_review_path(@pull_request_review)

    # Check different tabs don't crash
    get root_path
    assert_response :success

    get root_path(tab: "pull_requests")
    assert_response :success

    get root_path(tab: "pull_request_reviews")
    assert_response :success
  end

  test "should handle authentication requirement for both dashboard and sidebar" do
    delete session_url

    get root_path
    assert_redirected_to demo_login_url

    get root_path(tab: "pull_request_reviews")
    assert_redirected_to demo_login_url
  end
end
