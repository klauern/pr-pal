require "test_helper"

class PullRequestSyncerTest < ActiveSupport::TestCase
  # Mock data provider for testing
  class MockDataProvider
    attr_reader :expected_calls, :call_count

    def initialize(return_data)
      @return_data = return_data
      @expected_calls = []
      @call_count = 0
    end

    def fetch_repository_pull_requests(repository, user)
      @call_count += 1
      @expected_calls << { repository: repository, user: user }

      if @return_data.is_a?(Proc)
        @return_data.call
      else
        @return_data
      end
    end

    def fetch_pr_ci_statuses(owner, repo, pr_number, user)
      # Implementation of fetch_pr_ci_statuses method
    end
  end
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    @syncer = PullRequestSyncer.new(@repository)

    # Sample PR data for testing direct method calls
    @sample_pr_data = {
      github_pr_number: 1,
      title: "Add new feature",
      body: "This PR adds a new feature to the application.",
      state: "open",
      author: "contributor",
      github_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      github_created_at: Time.parse("2025-01-01T10:00:00Z"),
      github_updated_at: Time.parse("2025-01-02T15:30:00Z")
    }
  end

  # sync_pull_request method tests (private method testing)
  test "should create new PR from data" do
    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.send(:sync_pull_request, @sample_pr_data)
    end

    pr = @repository.pull_requests.last
    assert_equal 1, pr.github_pr_id
    assert_equal "Add new feature", pr.title
    assert_equal "open", pr.state
    assert_equal "contributor", pr.author
    assert_equal "This PR adds a new feature to the application.", pr.body
    assert_equal "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1", pr.github_pr_url
  end

  test "should update existing PR with new data" do
    # Create existing PR
    existing_pr = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      title: "Old title",
      state: "open",
      author: "old_author",
      github_created_at: 1.week.ago,
      github_updated_at: 1.week.ago
    )

    # Sync with updated data
    updated_data = @sample_pr_data.merge(
      title: "Updated title",
      state: "closed",
      body: "Updated body content"
    )

    assert_no_difference "@repository.pull_requests.count" do
      @syncer.send(:sync_pull_request, updated_data)
    end

    existing_pr.reload
    assert_equal "Updated title", existing_pr.title
    assert_equal "closed", existing_pr.state
    assert_equal "Updated body content", existing_pr.body
    assert_equal "contributor", existing_pr.author  # Should be updated
  end

  test "should handle validation failures gracefully" do
    invalid_data = @sample_pr_data.merge(title: "")  # Empty title should fail validation

    assert_no_difference "@repository.pull_requests.count" do
      assert_raises RuntimeError do
        @syncer.send(:sync_pull_request, invalid_data)
      end
    end
  end

  test "should correctly parse timestamps" do
    @syncer.send(:sync_pull_request, @sample_pr_data)

    pr = @repository.pull_requests.last
    assert_equal Time.parse("2025-01-01T10:00:00Z"), pr.github_created_at
    assert_equal Time.parse("2025-01-02T15:30:00Z"), pr.github_updated_at
  end

  test "should handle missing optional fields" do
    minimal_data = {
      github_pr_number: 1,
      title: "Minimal PR",
      state: "open",
      author: "contributor",
      github_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      github_created_at: Time.parse("2025-01-01T10:00:00Z"),
      github_updated_at: Time.parse("2025-01-01T10:00:00Z")
      # Missing: body, additions, deletions, etc.
    }

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.send(:sync_pull_request, minimal_data)
    end

    pr = @repository.pull_requests.last
    assert_equal "Minimal PR", pr.title
    assert_nil pr.body
  end

  test "should handle special characters in PR data" do
    special_data = @sample_pr_data.merge(
      title: "Fix: Handle émojis 🚀 and spëcial chârs",
      body: "This PR fixes issues with unicode: 中文, العربية, русский",
      author: "usér-with-spëcial-chars"
    )

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.send(:sync_pull_request, special_data)
    end

    pr = @repository.pull_requests.last
    assert_equal "Fix: Handle émojis 🚀 and spëcial chârs", pr.title
    assert_includes pr.body, "中文"
    assert_equal "usér-with-spëcial-chars", pr.author
  end

  test "should handle very long titles and bodies" do
    long_title = "A" * 1000
    long_body = "B" * 10000

    long_data = @sample_pr_data.merge(
      title: long_title,
      body: long_body
    )

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.send(:sync_pull_request, long_data)
    end

    pr = @repository.pull_requests.last
    assert_equal long_title, pr.title
    assert_equal long_body, pr.body
  end

  # Syncer initialization tests
  test "should initialize with repository" do
    syncer = PullRequestSyncer.new(@repository)
    assert_equal @repository, syncer.instance_variable_get(:@repository)
  end

  test "should require repository for initialization" do
    assert_raises NoMethodError do
      PullRequestSyncer.new(nil)
    end
  end

  # Integration with existing data
  test "should handle conflicts with existing PRs gracefully" do
    # Create a PR that will be updated
    existing_pr = PullRequest.create!(
      repository: @repository,
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      title: "Original Title",
      state: "open",
      author: "original_author",
      github_created_at: 1.day.ago,
      github_updated_at: 1.day.ago
    )

    # Should update, not create new
    result = @syncer.send(:sync_pull_request, @sample_pr_data)

    assert result.persisted?
    assert_equal existing_pr.id, result.id
    assert_equal "Add new feature", result.title  # Should be updated
  end

  # sync! method tests (main public interface)
  test "should sync successfully with multiple PRs" do
    # Mock the data provider to return sample data
    mock_provider = MockDataProvider.new([
      @sample_pr_data,
      @sample_pr_data.merge(
        github_pr_number: 2,
        title: "Second PR",
        github_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/2"
      )
    ])

    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 2 do
      result = @syncer.sync!

      assert_equal 2, result[:synced]
      assert_empty result[:errors]
      assert_equal :success, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle empty repository with no PRs" do
    mock_provider = MockDataProvider.new([])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_no_difference "@repository.pull_requests.count" do
      result = @syncer.sync!

      assert_equal 0, result[:synced]
      assert_empty result[:errors]
      assert_equal :no_prs, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle data provider errors gracefully" do
    mock_provider = MockDataProvider.new(-> { raise StandardError.new("GitHub API error") })
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_no_difference "@repository.pull_requests.count" do
      result = @syncer.sync!

      assert_equal 0, result[:synced]
      assert_equal 1, result[:errors].size
      assert_includes result[:errors].first, "GitHub API error"
      assert_equal :error, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle partial failures in PR processing" do
    # One valid PR and one invalid PR
    invalid_pr_data = @sample_pr_data.merge(
      github_pr_number: 2,
      title: "",  # Empty title should fail validation
      github_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/2"
    )

    mock_provider = MockDataProvider.new([
      @sample_pr_data,      # This should succeed
      invalid_pr_data       # This should fail validation
    ])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 1 do
      result = @syncer.sync!

      assert_equal 1, result[:synced]
      assert_equal 1, result[:errors].size
      assert_includes result[:errors].first, "Failed to sync PR #2"
      assert_equal :partial_success, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle validation errors for individual PRs" do
    # Create invalid PR data
    invalid_pr_data = @sample_pr_data.merge(title: "")  # Empty title

    mock_provider = MockDataProvider.new([ invalid_pr_data ])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_no_difference "@repository.pull_requests.count" do
      result = @syncer.sync!

      assert_equal 0, result[:synced]
      assert_equal 1, result[:errors].size
      assert_includes result[:errors].first, "Validation failed"
      assert_equal :partial_success, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle generic errors for individual PRs" do
    # Mock sync_pull_request to raise an error
    @syncer.define_singleton_method(:sync_pull_request) do |pr_data|
      raise StandardError.new("Unexpected error")
    end

    mock_provider = MockDataProvider.new([ @sample_pr_data ])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_no_difference "@repository.pull_requests.count" do
      result = @syncer.sync!

      assert_equal 0, result[:synced]
      assert_equal 1, result[:errors].size
      assert_includes result[:errors].first, "Failed to sync PR #1"
      assert_includes result[:errors].first, "Unexpected error"
      assert_equal :partial_success, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should update repository timestamp after sync" do
    mock_provider = MockDataProvider.new([ @sample_pr_data ])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    original_updated_at = @repository.updated_at

    travel 1.minute do
      @syncer.sync!
      @repository.reload
      assert @repository.updated_at > original_updated_at
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should handle concurrent sync operations" do
    # Create separate mock providers for each syncer
    mock_provider1 = MockDataProvider.new([ @sample_pr_data ])
    mock_provider2 = MockDataProvider.new([ @sample_pr_data ])

    # Create two syncers for the same repository
    syncer1 = PullRequestSyncer.new(@repository)
    syncer2 = PullRequestSyncer.new(@repository)

    syncer1.instance_variable_set(:@data_provider, mock_provider1)
    syncer2.instance_variable_set(:@data_provider, mock_provider2)

    # Run concurrent syncs
    threads = [
      Thread.new { syncer1.sync! },
      Thread.new { syncer2.sync! }
    ]

    results = threads.map(&:join).map(&:value)

    # At least one should succeed
    assert results.any? { |result| result[:status] == :success || result[:status] == :partial_success }

    assert_equal 1, mock_provider1.call_count
    assert_equal 1, mock_provider2.call_count
  end

  test "should log sync operations appropriately" do
    mock_provider = MockDataProvider.new([ @sample_pr_data ])
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    # Capture log output
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    begin
      @syncer.sync!

      log_content = log_output.string
      assert_includes log_content, "Starting PR sync"
      assert_includes log_content, "PR sync completed"
      assert_includes log_content, @repository.full_name
    ensure
      Rails.logger = original_logger
    end

    assert_equal 1, mock_provider.call_count
  end

  test "should initialize data provider correctly" do
    # In test environment, encryption is disabled, so GitHub tokens work differently
    # Just test that a data provider is assigned
    syncer = PullRequestSyncer.new(@repository)
    assert_not_nil syncer.data_provider
    assert syncer.data_provider.respond_to?(:fetch_repository_pull_requests)
  end

  test "should use appropriate provider based on user configuration" do
    # Test that the factory returns a valid provider
    syncer = PullRequestSyncer.new(@repository)

    # Should get a valid provider class
    assert [ GithubPullRequestDataProvider, DummyPullRequestDataProvider ].include?(syncer.data_provider)
  end

  test "should raise error when initialized with nil repository" do
    assert_raises NoMethodError do
      PullRequestSyncer.new(nil)
    end
  end

  test "should handle very large PR data sets" do
    # Generate a large set of PR data
    large_pr_set = (1..100).map do |i|
      @sample_pr_data.merge(
        github_pr_number: i,
        title: "PR ##{i}",
        github_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/#{i}"
      )
    end

    mock_provider = MockDataProvider.new(large_pr_set)
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 100 do
      result = @syncer.sync!

      assert_equal 100, result[:synced]
      assert_empty result[:errors]
      assert_equal :success, result[:status]
    end

    assert_equal 1, mock_provider.call_count
  end

  # --- CI/CD Status Tests ---
  test "should store ci_status and ci_status_raw when data provider returns CI/CD status" do
    pr_data = @sample_pr_data.merge(github_pr_number: 99)
    mock_provider = MockDataProvider.new([ pr_data ])
    # Stub fetch_pr_ci_statuses to simulate CI/CD status
    def mock_provider.fetch_pr_ci_statuses(owner, repo, pr_number, user)
      {
        sha: "abc123",
        statuses: [
          { type: :status, context: "ci/circleci", state: "success", description: "CircleCI passed", target_url: "http://ci.example.com/1" }
        ],
        check_runs: [
          { type: :check_run, name: "build", status: "completed", conclusion: "success", details_url: "http://ci.example.com/2", output_title: "Build passed", output_summary: "All good" }
        ]
      }
    end
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.sync!
    end
    pr = @repository.pull_requests.find_by(github_pr_id: 99)
    assert_equal "success", pr.ci_status
    assert pr.ci_status_raw.include?("CircleCI passed")
    assert pr.ci_status_raw.include?("Build passed")
    assert pr.ci_status_updated_at.present?
  end

  test "should store ci_status as failure if any check_run fails" do
    pr_data = @sample_pr_data.merge(github_pr_number: 100)
    mock_provider = MockDataProvider.new([ pr_data ])
    def mock_provider.fetch_pr_ci_statuses(owner, repo, pr_number, user)
      {
        sha: "def456",
        statuses: [],
        check_runs: [
          { type: :check_run, name: "test", status: "completed", conclusion: "failure", details_url: "http://ci.example.com/3", output_title: "Test failed", output_summary: "Some tests failed" }
        ]
      }
    end
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.sync!
    end
    pr = @repository.pull_requests.find_by(github_pr_id: 100)
    assert_equal "failure", pr.ci_status
    assert pr.ci_status_raw.include?("Test failed")
  end

  test "should store ci_status as pending if any check_run is in progress" do
    # Use a unique PR number that doesn't conflict with fixtures
    pr_data = @sample_pr_data.merge(github_pr_number: 99101)
    mock_provider = MockDataProvider.new([ pr_data ])
    def mock_provider.fetch_pr_ci_statuses(owner, repo, pr_number, user)
      {
        sha: "ghi789",
        statuses: [],
        check_runs: [
          { type: :check_run, name: "deploy", status: "in_progress", conclusion: nil, details_url: "http://ci.example.com/4", output_title: "Deploying", output_summary: "Deployment running" }
        ]
      }
    end
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.sync!
    end
    pr = @repository.pull_requests.find_by(github_pr_id: 99101)
    assert_equal "pending", pr.ci_status
    assert pr.ci_status_raw.include?("Deploying")
  end

  test "should store ci_status as none if no statuses or check_runs" do
    pr_data = @sample_pr_data.merge(github_pr_number: 102)
    mock_provider = MockDataProvider.new([ pr_data ])
    def mock_provider.fetch_pr_ci_statuses(owner, repo, pr_number, user)
      { sha: "jkl012", statuses: [], check_runs: [] }
    end
    @syncer.instance_variable_set(:@data_provider, mock_provider)

    assert_difference "@repository.pull_requests.count", 1 do
      @syncer.sync!
    end
    pr = @repository.pull_requests.find_by(github_pr_id: 102)
    assert_equal "none", pr.ci_status
    assert pr.ci_status_raw.include?("statuses")
    assert pr.ci_status_raw.include?("check_runs")
  end

  # --- Integration test (real GitHub API, requires valid token) ---
  test "integration: should fetch and store real ci_status for octocat/hello-world PR if token configured" do
    user = users(:one)
    repo = repositories(:one)
    # Only run if a GitHub token is configured
    if user.github_token_configured?
      syncer = PullRequestSyncer.new(repo)
      assert_nothing_raised do
        syncer.sync!
      end
      pr = repo.pull_requests.first
      assert pr.ci_status.present?
      assert pr.ci_status_raw.present?
      assert pr.ci_status_updated_at.present?
    else
      skip "No GitHub token configured for integration test."
    end
  end
end
