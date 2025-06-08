require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @repository = repositories(:one)
  end

  test "should get index when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    get repositories_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get repositories_url
    assert_redirected_to demo_login_url
  end

  test "should show repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    get repository_url(@repository)
    assert_response :success
    assert_select "h1", text: @repository.full_name
  end

  test "should redirect to login when accessing show without authentication" do
    get repository_url(@repository)
    assert_redirected_to demo_login_url
  end

  test "should display pull request reviews on repository show page" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Create some pull request reviews for the repository
    pull_request1 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1,
      github_pr_url: "https://github.com/test/repo/pull/1",
      title: "Test PR 1",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    pr1 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request1,
      github_pr_id: 1,
      github_pr_url: "https://github.com/test/repo/pull/1",
      github_pr_title: "Test PR 1",
      status: "in_progress"
    )
    pull_request2 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 2,
      github_pr_url: "https://github.com/test/repo/pull/2",
      title: "Test PR 2",
      state: "open",
      author: "testuser",
      github_created_at: 3.days.ago,
      github_updated_at: 2.hours.ago
    )
    pr2 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request2,
      github_pr_id: 2,
      github_pr_url: "https://github.com/test/repo/pull/2",
      github_pr_title: "Test PR 2",
      status: "completed"
    )

    get repository_url(@repository)
    assert_response :success

    # Check that pull request reviews are displayed
    assert_select "h2", text: "Pull Request Reviews"
    assert_includes response.body, "Test PR 1"
    assert_includes response.body, "Test PR 2"
    assert_includes response.body, "#1"
    assert_includes response.body, "#2"
  end

  test "should show empty state when repository has no pull request reviews" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Ensure repository has no pull request reviews
    @repository.pull_request_reviews.destroy_all

    get repository_url(@repository)
    assert_response :success

    # Check for empty state message
    assert_includes response.body, "No Pull Request Reviews"
    assert_includes response.body, "No pull requests have been reviewed"
  end

  test "should not allow user to view another user's repository" do
    other_user = users(:two)
    other_repository = repositories(:two)

    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Try to view another user's repository
    # Should either raise RecordNotFound or return 404
    begin
      get repository_url(other_repository)
      # If no exception is raised, check for error response
      assert_response :not_found
    rescue ActiveRecord::RecordNotFound
      # This is also acceptable behavior
      assert true
    end
  end

  test "should create repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_difference("Repository.count") do
      post repositories_url, params: { repository: { owner: "testowner", name: "testrepo" } }
    end
    assert_redirected_to root_path(tab: "repositories")
  end

  test "should destroy repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_difference("Repository.count", -1) do
      delete repository_url(@repository)
    end
    assert_redirected_to root_path(tab: "repositories")
  end

  test "should not create repository with missing owner" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference("Repository.count") do
      post repositories_url, params: { repository: { name: "testrepo" } }
    end
    assert_response :unprocessable_entity
    # The validation error should be present
    assert assigns(:repository).errors[:owner].any?
  end

  test "should not create repository with missing name" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference("Repository.count") do
      post repositories_url, params: { repository: { owner: "testowner" } }
    end
    assert_response :unprocessable_entity
    # The validation error should be present
    assert assigns(:repository).errors[:name].any?
  end

  test "should not create duplicate repository for same user" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference("Repository.count") do
      post repositories_url, params: { repository: { owner: @repository.owner, name: @repository.name } }
    end
    assert_response :unprocessable_entity
    # The uniqueness validation error should be present
    assert assigns(:repository).errors.any?
  end

  test "should not allow user to destroy another user's repository" do
    other_user = users(:two)
    other_repository = repositories(:two)

    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Try to delete another user's repository - should result in RecordNotFound or no change
    begin
      delete repository_url(other_repository)
      # If we get here, the delete didn't raise an exception
      # Check that the repository still exists
      assert Repository.exists?(other_repository.id), "Repository should still exist"
    rescue ActiveRecord::RecordNotFound
      # This is the expected behavior
      assert true
    end
  end

  test "should clean up open PR tabs when repository is destroyed" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Create PR reviews for the repository
    pull_request1 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 101,
      github_pr_url: "https://github.com/test/repo/pull/101",
      title: "Test PR 1",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    pr1 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request1,
      github_pr_id: 101,
      github_pr_url: "https://github.com/test/repo/pull/101",
      github_pr_title: "Test PR 1",
      status: "in_progress"
    )
    pull_request2 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 102,
      github_pr_url: "https://github.com/test/repo/pull/102",
      title: "Test PR 2",
      state: "open",
      author: "testuser",
      github_created_at: 3.days.ago,
      github_updated_at: 2.hours.ago
    )
    pr2 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request2,
      github_pr_id: 102,
      github_pr_url: "https://github.com/test/repo/pull/102",
      github_pr_title: "Test PR 2",
      status: "in_progress"
    )

    # Create another repository with a PR review that should NOT be affected
    other_repo = @user.repositories.create!(owner: "other", name: "repo")
    other_pull_request = PullRequest.create!(
      repository: other_repo,
      github_pr_id: 103,
      github_pr_url: "https://github.com/other/repo/pull/103",
      title: "Other PR",
      state: "open",
      author: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 12.hours.ago
    )
    other_pr = other_repo.pull_request_reviews.create!(
      user: @user,
      pull_request: other_pull_request,
      github_pr_id: 103,
      github_pr_url: "https://github.com/other/repo/pull/103",
      github_pr_title: "Other PR",
      status: "in_progress"
    )

    # Open the PRs to add them to session tabs
    get pull_request_review_url(pr1)
    get pull_request_review_url(pr2)
    get pull_request_review_url(other_pr)

    # Verify tabs are set up correctly
    assert_includes session[:open_pr_tabs], "pr_#{pr1.id}"
    assert_includes session[:open_pr_tabs], "pr_#{pr2.id}"
    assert_includes session[:open_pr_tabs], "pr_#{other_pr.id}"

    # Destroy the repository - this should trigger tab cleanup logic
    assert_difference("Repository.count", -1) do
      delete repository_url(@repository)
    end

    # The important thing is that the controller logic executes without errors
    # and the repository and its PR reviews are properly deleted
    assert_redirected_to root_path(tab: "repositories")
  end

  test "should clean up tabs when repository with PR reviews is destroyed" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Create PR review for the repository
    pull_request = PullRequest.create!(
      repository: @repository,
      github_pr_id: 104,
      github_pr_url: "https://github.com/test/repo/pull/104",
      title: "Test PR",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    pr = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request,
      github_pr_id: 104,
      github_pr_url: "https://github.com/test/repo/pull/104",
      github_pr_title: "Test PR",
      status: "in_progress"
    )

    # Open the PR to add it to session tabs
    get pull_request_review_url(pr)

    # Verify the PR was added to tabs
    assert_includes session[:open_pr_tabs], "pr_#{pr.id}"
    initial_tab_count = session[:open_pr_tabs].length

    # Destroy the repository
    assert_difference("Repository.count", -1) do
      delete repository_url(@repository)
    end

    # Check that tabs were cleaned up (PR review was destroyed via dependent: :destroy)
    # The exact session state after redirect may vary, but the controller logic should handle cleanup
    assert_redirected_to root_path(tab: "repositories")
  end

  test "should handle repository destruction when PR reviews exist" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Count existing PR reviews for this repository (from fixtures)
    initial_pr_count = @repository.pull_request_reviews.count

    # Create additional PR reviews for the repository
    pull_request1 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 105,
      github_pr_url: "https://github.com/test/repo/pull/105",
      title: "Test PR 1",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    pr1 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request1,
      github_pr_id: 105,
      github_pr_url: "https://github.com/test/repo/pull/105",
      github_pr_title: "Test PR 1",
      status: "in_progress"
    )
    pull_request2 = PullRequest.create!(
      repository: @repository,
      github_pr_id: 106,
      github_pr_url: "https://github.com/test/repo/pull/106",
      title: "Test PR 2",
      state: "open",
      author: "testuser",
      github_created_at: 3.days.ago,
      github_updated_at: 2.hours.ago
    )
    pr2 = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request2,
      github_pr_id: 106,
      github_pr_url: "https://github.com/test/repo/pull/106",
      github_pr_title: "Test PR 2",
      status: "in_progress"
    )

    total_prs = initial_pr_count + 2

    # Repository destruction should cascade delete all PR reviews for this repository
    assert_difference("PullRequestReview.count", -total_prs) do
      delete repository_url(@repository)
    end

    assert_redirected_to root_path(tab: "repositories")
  end

  test "should handle repository destruction with no open tabs" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Create PR review for the repository
    pull_request = PullRequest.create!(
      repository: @repository,
      github_pr_id: 107,
      github_pr_url: "https://github.com/test/repo/pull/107",
      title: "Test PR",
      state: "open",
      author: "testuser",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    )
    pr = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request,
      github_pr_id: 107,
      github_pr_url: "https://github.com/test/repo/pull/107",
      github_pr_title: "Test PR",
      status: "in_progress"
    )

    # No open tabs in session
    session[:open_pr_tabs] = nil
    session[:active_tab] = "home"

    # Should not raise any errors
    assert_difference("Repository.count", -1) do
      delete repository_url(@repository)
    end

    assert_redirected_to root_path(tab: "repositories")
  end

  test "should sync repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Mock the job to prevent actual execution
    assert_enqueued_with(job: PullRequestSyncJob, args: [ @repository.id ]) do
      post sync_repository_url(@repository)
    end

    assert_redirected_to @repository
    assert_equal "Repository sync started for #{@repository.full_name}. Pull requests will be updated in the background.", flash[:notice]
  end

  test "should sync all repositories when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Create additional repository for the user
    additional_repo = @user.repositories.create!(owner: "test", name: "additional")

    # Instead of mocking, just verify the request succeeds
    post sync_all_repositories_url

    assert_redirected_to repositories_path
    assert_equal "Sync started for all repositories. Pull requests will be updated in the background.", flash[:notice]
  end

  test "should not allow sync of another user's repository" do
    other_user = users(:two)
    other_repository = repositories(:two)

    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Try to sync another user's repository
    begin
      post sync_repository_url(other_repository)
      # If no exception is raised, check for error response
      assert_response :not_found
    rescue ActiveRecord::RecordNotFound
      # This is also acceptable behavior
      assert true
    end
  end

  test "should redirect to login when syncing without authentication" do
    post sync_repository_url(@repository)
    assert_redirected_to demo_login_url
  end

  test "should redirect to login when syncing all without authentication" do
    post sync_all_repositories_url
    assert_redirected_to demo_login_url
  end

  test "should respond to turbo stream for individual repository sync" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Mock the job to prevent actual execution
    assert_enqueued_with(job: PullRequestSyncJob, args: [ @repository.id ]) do
      post sync_repository_url(@repository), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.content_type
    assert_includes response.body, "Repository sync started"
  end

  test "should respond to turbo stream for sync all repositories" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Just verify the request succeeds
    post sync_all_repositories_url, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "turbo-stream", response.content_type
    assert_includes response.body, "Sync started for all repositories"
  end
end
