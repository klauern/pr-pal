require "test_helper"

class PullRequestReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:sample_review)
    @completed_review = pull_request_reviews(:completed_review)

    # Authenticate user for all tests
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  # Authentication Tests
  test "should redirect to login when not authenticated for index" do
    delete session_url
    get pull_request_reviews_url
    assert_redirected_to demo_login_url
  end

  test "should redirect to login when not authenticated for show" do
    delete session_url
    get pull_request_review_url(@pull_request_review)
    assert_redirected_to demo_login_url
  end

  test "should redirect to login when not authenticated for create" do
    delete session_url
    post pull_request_reviews_url, params: { repository_id: @repository.id, pull_request_review: { github_pr_id: 999 } }
    assert_redirected_to demo_login_url
  end

  # Index Action Tests
  test "should get index" do
    get pull_request_reviews_url
    assert_response :success
    assert_includes response.body, @pull_request_review.github_pr_title
  end

  test "should only show in_progress reviews in index" do
    get pull_request_reviews_url
    assert_includes response.body, @pull_request_review.github_pr_title
    assert_not_includes response.body, @completed_review.github_pr_title
  end

  # Show Action Tests
  test "should show pull request review" do
    get pull_request_review_url(@pull_request_review)
    assert_response :success
    assert_includes response.body, @pull_request_review.github_pr_title
  end

  test "should mark review as viewed on show" do
    original_viewed_at = @pull_request_review.last_viewed_at
    get pull_request_review_url(@pull_request_review)
    @pull_request_review.reload
    assert @pull_request_review.last_viewed_at > original_viewed_at
  end

  test "should add PR to tabs on show" do
    get pull_request_review_url(@pull_request_review)
    assert_includes session[:open_pr_tabs], "pr_#{@pull_request_review.id}"
  end

  test "should not allow access to other user's reviews" do
    other_user = users(:two)
    other_repo = repositories(:two)
    pull_request = PullRequest.create!(
      repository: other_repo,
      github_pr_id: 789,
      github_pr_url: "https://github.com/test/test/pull/789",
      title: "Other user's review",
      state: "open",
      author: "testuser"
    )
    other_review = PullRequestReview.create!(
      user: other_user,
      repository: other_repo,
      pull_request: pull_request,
      github_pr_id: 789,
      github_pr_url: "https://github.com/test/test/pull/789",
      github_pr_title: "Other user's review"
    )

    get pull_request_review_url(other_review)
    # Should get a 404 or redirect due to authorization
    assert_response :not_found
  rescue ActiveRecord::RecordNotFound
    # This is the expected behavior
    assert true
  end

  # Create Action Tests
  test "should create pull request review with HTML format" do
    assert_difference("PullRequestReview.count") do
      post pull_request_reviews_url, params: {
        repository_id: @repository.id,
        pull_request_review: {
          github_pr_id: 999,
          github_pr_url: "https://github.com/test/test/pull/999",
          github_pr_title: "New test PR"
        }
      }
    end
    assert_redirected_to root_path(tab: "pull_request_reviews")
    assert_equal "Pull request review started.", flash[:notice]
  end

  test "should create pull request review with Turbo Stream format" do
    assert_difference("PullRequestReview.count") do
      post pull_request_reviews_url, params: {
        repository_id: @repository.id,
        pull_request_review: {
          github_pr_id: 999,
          github_pr_url: "https://github.com/test/test/pull/999",
          github_pr_title: "New test PR"
        }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "Pull request review started."
  end

  test "should add new PR to tabs after creation" do
    post pull_request_reviews_url, params: {
      repository_id: @repository.id,
      pull_request_review: {
        github_pr_id: 999,
        github_pr_url: "https://github.com/test/test/pull/999",
        github_pr_title: "New test PR"
      }
    }
    new_review = PullRequestReview.last
    assert_includes session[:open_pr_tabs], "pr_#{new_review.id}"
  end

  test "should handle validation errors in create" do
    assert_no_difference("PullRequestReview.count") do
      post pull_request_reviews_url, params: {
        repository_id: @repository.id,
        pull_request_review: {
          github_pr_id: nil, # Invalid - required field
          github_pr_url: "invalid-url",
          github_pr_title: ""
        }
      }
    end
    assert_redirected_to root_path(tab: "repositories")
    assert_includes flash[:alert], "Failed to start review"
  end

  test "should handle validation errors in create with Turbo Stream" do
    assert_no_difference("PullRequestReview.count") do
      post pull_request_reviews_url, params: {
        repository_id: @repository.id,
        pull_request_review: {
          github_pr_id: nil,
          github_pr_url: "invalid-url",
          github_pr_title: ""
        }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_includes response.body, "Failed to start review"
  end

  # Update Action Tests
  test "should update pull request review" do
    patch pull_request_review_url(@pull_request_review), params: {
      pull_request_review: { llm_context_summary: "Updated summary" }
    }
    assert_redirected_to pull_request_review_path(@pull_request_review)
    assert_equal "Review updated successfully", flash[:notice]
    @pull_request_review.reload
    assert_equal "Updated summary", @pull_request_review.llm_context_summary
  end

  test "should update pull request review with Turbo Stream" do
    patch pull_request_review_url(@pull_request_review), params: {
      pull_request_review: { llm_context_summary: "Updated summary" }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_includes response.body, "Review updated successfully"
  end

  test "should complete review via update action" do
    patch pull_request_review_url(@pull_request_review), params: {
      action_type: "complete"
    }
    assert_redirected_to root_path(tab: "pull_request_reviews")
    assert_equal "Review marked as complete", flash[:notice]
    @pull_request_review.reload
    assert_equal "completed", @pull_request_review.status
  end

  test "should complete review with Turbo Stream format" do
    patch pull_request_review_url(@pull_request_review), params: {
      action_type: "complete"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_includes response.body, "Review marked as complete"
  end

  test "should complete review with JSON format" do
    patch pull_request_review_url(@pull_request_review), params: {
      action_type: "complete"
    }, headers: { "Accept" => "application/json" }
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "completed", json_response["status"]
    assert_equal "Review marked as complete", json_response["message"]
  end

  test "should handle update validation errors" do
    patch pull_request_review_url(@pull_request_review), params: {
      pull_request_review: { github_pr_id: nil } # Invalid
    }
    assert_redirected_to pull_request_review_path(@pull_request_review)
    assert_includes flash[:alert], "Failed to update review"
  end

  test "should handle update validation errors with JSON" do
    patch pull_request_review_url(@pull_request_review), params: {
      pull_request_review: { github_pr_id: nil }
    }, headers: { "Accept" => "application/json" }
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "error", json_response["status"]
    assert json_response["errors"].any?
  end

  # Destroy Action Tests
  test "should destroy pull request review" do
    pr_id = @pull_request_review.id
    session[:open_pr_tabs] = [ "pr_#{pr_id}" ]

    assert_difference("PullRequestReview.count", -1) do
      delete pull_request_review_url(@pull_request_review)
    end
    assert_redirected_to root_path(tab: "pull_request_reviews")
    assert_equal "Pull request review deleted.", flash[:notice]
    assert_not_includes session[:open_pr_tabs], "pr_#{pr_id}"
  end

  # Close Tab Action Tests
  test "should close tab with numeric ID" do
    pr_id = @pull_request_review.id
    session[:open_pr_tabs] = [ "pr_#{pr_id}" ]

    delete close_pr_tab_url(pr_id: pr_id)
    assert_redirected_to root_path(tab: "pull_request_reviews")
    assert_not_includes session[:open_pr_tabs], "pr_#{pr_id}"
  end

  test "should close tab with pr_ prefixed ID" do
    pr_id = @pull_request_review.id
    session[:open_pr_tabs] = [ "pr_#{pr_id}" ]

    delete close_pr_tab_url(pr_id: "pr_#{pr_id}")
    assert_redirected_to root_path(tab: "pull_request_reviews")
    assert_not_includes session[:open_pr_tabs], "pr_#{pr_id}"
  end

  # Reset Tabs Action Tests (Development only)
  test "should reset tabs in development" do
    skip "Reset tabs action is development-only feature"
  end

  # Tab Management Helper Method Tests
  test "should add PR to tabs correctly" do
    session[:open_pr_tabs] = []
    get pull_request_review_url(@pull_request_review)
    assert_includes session[:open_pr_tabs], "pr_#{@pull_request_review.id}"
  end

  test "should limit tabs to 5 most recent" do
    # Create multiple reviews and add them to tabs
    6.times do |i|
      pull_request = PullRequest.create!(
        repository: @repository,
        github_pr_id: 1000 + i,
        github_pr_url: "https://github.com/test/test/pull/#{1000 + i}",
        title: "Test PR #{i}",
        state: "open",
        author: "testuser"
      )
      review = PullRequestReview.create!(
        user: @user,
        repository: @repository,
        pull_request: pull_request,
        github_pr_id: 1000 + i,
        github_pr_url: "https://github.com/test/test/pull/#{1000 + i}",
        github_pr_title: "Test PR #{i}"
      )
      get pull_request_review_url(review)
    end

    assert_equal 5, session[:open_pr_tabs].length
  end

  test "should not duplicate tabs when accessing same PR multiple times" do
    get pull_request_review_url(@pull_request_review)
    get pull_request_review_url(@pull_request_review)
    get pull_request_review_url(@pull_request_review)

    tab_count = session[:open_pr_tabs].count("pr_#{@pull_request_review.id}")
    assert_equal 1, tab_count
  end

  test "should move accessed PR to end of tab list" do
    # Create another review and add both to tabs
    other_pull_request = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1001,
      github_pr_url: "https://github.com/test/test/pull/1001",
      title: "Other test PR",
      state: "open",
      author: "testuser"
    )
    other_review = PullRequestReview.create!(
      user: @user,
      repository: @repository,
      pull_request: other_pull_request,
      github_pr_id: 1001,
      github_pr_url: "https://github.com/test/test/pull/1001",
      github_pr_title: "Other test PR"
    )

    get pull_request_review_url(other_review)
    get pull_request_review_url(@pull_request_review)

    # Access the other review again - it should move to the end
    get pull_request_review_url(other_review)

    assert_equal "pr_#{other_review.id}", session[:open_pr_tabs].last
  end

  # Private method coverage for set_pull_request_review
  test "should find correct pull request review in set_pull_request_review" do
    # This is tested implicitly by all the other tests that access specific reviews
    get pull_request_review_url(@pull_request_review)
    assert_response :success
  end

  test "should handle non-existent pull request review in set_pull_request_review" do
    get pull_request_review_url(id: 99999)
    # Should get a 404 response
    assert_response :not_found
  rescue ActiveRecord::RecordNotFound
    # This is the expected behavior
    assert true
  end
end
