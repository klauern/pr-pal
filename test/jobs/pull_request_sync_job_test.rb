require "test_helper"
require "minitest/mock"

class PullRequestSyncJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @repository = repositories(:one)
  end

  test "should sync repository successfully" do
    # Mock the PullRequestSyncer
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync!, { status: :success, synced: 5, errors: [] }

    PullRequestSyncer.stub :new, mock_syncer do
      result = PullRequestSyncJob.perform_now(@repository.id)

      assert_equal :success, result[:status]
      assert_equal 5, result[:synced]
      assert_empty result[:errors]
    end

    mock_syncer.verify
  end

  test "should handle partial success" do
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync!, { status: :partial_success, synced: 3, errors: [ "Error 1", "Error 2" ] }

    PullRequestSyncer.stub :new, mock_syncer do
      result = PullRequestSyncJob.perform_now(@repository.id)

      assert_equal :partial_success, result[:status]
      assert_equal 3, result[:synced]
      assert_equal 2, result[:errors].size
    end

    mock_syncer.verify
  end

  test "should handle no PRs found" do
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync!, { status: :no_prs, synced: 0, errors: [] }

    PullRequestSyncer.stub :new, mock_syncer do
      result = PullRequestSyncJob.perform_now(@repository.id)

      assert_equal :no_prs, result[:status]
      assert_equal 0, result[:synced]
    end

    mock_syncer.verify
  end

  test "should handle sync error" do
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync!, { status: :error, synced: 0, errors: [ "API rate limit exceeded" ] }

    PullRequestSyncer.stub :new, mock_syncer do
      result = PullRequestSyncJob.perform_now(@repository.id)

      assert_equal :error, result[:status]
      assert_equal 0, result[:synced]
      assert_includes result[:errors], "API rate limit exceeded"
    end

    mock_syncer.verify
  end

  test "should handle repository not found" do
    result = PullRequestSyncJob.perform_now(999999)

    assert_equal :error, result[:status]
    assert_equal 0, result[:synced]
    assert_includes result[:errors], "Repository not found"
  end

  test "should handle syncer exception" do
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync!, proc { raise StandardError.new("Connection timeout") }

    PullRequestSyncer.stub :new, mock_syncer do
      result = PullRequestSyncJob.perform_now(@repository.id)

      assert_equal :error, result[:status]
      assert_equal 0, result[:synced]
      assert_includes result[:errors], "Connection timeout"
    end

    mock_syncer.verify
  end

  test "sync_user_repositories should process all user repositories" do
    # Create additional repository for the user
    @repository2 = Repository.create!(
      user: @user,
      owner: "user",
      name: "test-repo-2"
    )

    # Mock successful sync for all repositories belonging to the user
    mock_perform_now = proc do |repo_id|
      { status: :success, synced: 3, errors: [] }
    end

    PullRequestSyncJob.stub :perform_now, mock_perform_now do
      results = PullRequestSyncJob.sync_user_repositories(@user)

      # Check that we processed the expected number of repositories for this user
      user_repo_count = @user.repositories.count
      assert_equal user_repo_count, results.size

      # Verify all results have success status
      results.each do |result|
        assert_equal :success, result[:result][:status]
      end
    end

    # Clean up
    @repository2.destroy
  end

  test "sync_user_repositories should handle individual repository errors" do
    # Create additional repository for error testing
    @repository2 = Repository.create!(
      user: @user,
      owner: "user",
      name: "test-repo-2"
    )

    # Mock one success and one failure
    call_count = 0
    mock_perform_now = proc do |repo_id|
      call_count += 1
      if call_count == 1
        { status: :success, synced: 3, errors: [] }
      else
        raise StandardError.new("Repository sync failed")
      end
    end

    PullRequestSyncJob.stub :perform_now, mock_perform_now do
      results = PullRequestSyncJob.sync_user_repositories(@user)

      user_repo_count = @user.repositories.count
      assert_equal user_repo_count, results.size

      # At least one should be success, and one should be error
      success_count = results.count { |r| r[:result][:status] == :success }
      error_count = results.count { |r| r[:result][:status] == :error }

      assert_operator success_count, :>=, 1
      assert_operator error_count, :>=, 1

      # Check that error results contain the expected error message
      error_results = results.select { |r| r[:result][:status] == :error }
      assert error_results.any? { |r| r[:result][:errors].include?("Repository sync failed") }
    end

    # Clean up
    @repository2.destroy
  end

  test "sync_all_repositories should queue jobs for all repositories" do
    # Create test repositories
    repo1 = Repository.create!(user: @user, owner: "user", name: "repo1")
    repo2 = Repository.create!(user: @user, owner: "user", name: "repo2")

    # Track perform_later calls
    queued_repo_ids = []
    mock_perform_later = proc do |repo_id|
      queued_repo_ids << repo_id
      true
    end

    PullRequestSyncJob.stub :perform_later, mock_perform_later do
      result = PullRequestSyncJob.sync_all_repositories

      # Should include our existing repository plus the new ones
      expected_count = Repository.count
      assert_equal expected_count, result[:total]
      assert_equal expected_count, result[:queued]
      assert_equal 0, result[:errors]

      # Should have queued jobs for all repositories
      assert_includes queued_repo_ids, @repository.id
      assert_includes queued_repo_ids, repo1.id
      assert_includes queued_repo_ids, repo2.id
    end

    # Clean up
    repo1.destroy
    repo2.destroy
  end

  test "sync_all_repositories should handle queueing errors" do
    # Mock perform_later to fail for some repositories
    call_count = 0
    mock_perform_later = proc do |repo_id|
      call_count += 1
      if call_count <= 1
        true  # First call succeeds
      else
        raise StandardError.new("Queue full")  # Subsequent calls fail
      end
    end

    # Create additional repository to test error handling
    repo1 = Repository.create!(user: @user, owner: "user", name: "repo1")

    PullRequestSyncJob.stub :perform_later, mock_perform_later do
      result = PullRequestSyncJob.sync_all_repositories

      total_repos = Repository.count
      assert_equal total_repos, result[:total]
      assert_equal 1, result[:queued]  # Only one succeeded
      assert_equal total_repos - 1, result[:errors]  # The rest failed
    end

    # Clean up
    repo1.destroy
  end
end
