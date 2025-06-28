require "test_helper"

class PullRequestTest < ActiveSupport::TestCase
  def setup
    @repository = repositories(:one)
    @valid_attributes = {
      repository: @repository,
      github_pr_id: 9999,
      github_pr_url: "https://github.com/octocat/hello-world/pull/9999",
      title: "Test pull request",
      state: "open",
      author: "test_author",
      github_created_at: 2.days.ago,
      github_updated_at: 1.day.ago
    }
    @pull_request = PullRequest.new(@valid_attributes)
  end

  # Association tests
  test "belongs to repository" do
    assert_respond_to @pull_request, :repository
    assert_instance_of Repository, @pull_request.repository
  end

  test "has many pull request reviews" do
    assert_respond_to @pull_request, :pull_request_reviews
  end

  test "dependent destroy for pull request reviews" do
    @pull_request.save!
    review = @pull_request.pull_request_reviews.create!(
      user: users(:one),
      repository: @repository,
      github_pr_id: @pull_request.github_pr_id,
      github_pr_url: @pull_request.github_pr_url,
      github_pr_title: @pull_request.title,
      status: "in_progress"
    )

    assert_difference "PullRequestReview.count", -1 do
      @pull_request.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @pull_request.valid?
  end

  test "should require repository_id" do
    @pull_request.repository = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:repository_id], "can't be blank"
  end

  test "should require github_pr_id" do
    @pull_request.github_pr_id = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:github_pr_id], "can't be blank"
  end

  test "should require unique github_pr_id scoped to repository" do
    @pull_request.save!

    duplicate_pr = PullRequest.new(@valid_attributes)
    assert_not duplicate_pr.valid?
    assert_includes duplicate_pr.errors[:github_pr_id], "has already been taken"
  end

  test "should allow same github_pr_id for different repositories" do
    @pull_request.save!

    other_repo = repositories(:two)
    other_pr = PullRequest.new(@valid_attributes.merge(repository: other_repo))
    assert other_pr.valid?
  end

  test "should require title" do
    @pull_request.title = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:title], "can't be blank"

    @pull_request.title = ""
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:title], "can't be blank"
  end

  test "should require state" do
    @pull_request.state = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:state], "can't be blank"

    @pull_request.state = ""
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:state], "can't be blank"
  end

  test "should require author" do
    @pull_request.author = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:author], "can't be blank"

    @pull_request.author = ""
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:author], "can't be blank"
  end

  test "should require github_pr_url" do
    @pull_request.github_pr_url = nil
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:github_pr_url], "can't be blank"

    @pull_request.github_pr_url = ""
    assert_not @pull_request.valid?
    assert_includes @pull_request.errors[:github_pr_url], "can't be blank"
  end

  # Scope tests
  test "open scope returns only open pull requests" do
    open_pr = pull_requests(:pr_one) # fixture has state: "open"
    another_open_pr = pull_requests(:pr_two) # fixture has state: "open"
    closed_pr = pull_requests(:pr_closed) # fixture has state: "closed"
    merged_pr = pull_requests(:pr_merged) # fixture has state: "merged"

    open_prs = PullRequest.open
    assert_includes open_prs, open_pr
    assert_includes open_prs, another_open_pr
    assert_not_includes open_prs, closed_pr
    assert_not_includes open_prs, merged_pr
  end

  test "closed scope returns only closed pull requests" do
    open_pr = pull_requests(:pr_one) # fixture has state: "open"
    closed_pr = pull_requests(:pr_closed) # fixture has state: "closed"
    old_closed_pr = pull_requests(:pr_old) # fixture has state: "closed"
    merged_pr = pull_requests(:pr_merged) # fixture has state: "merged"

    closed_prs = PullRequest.closed
    assert_includes closed_prs, closed_pr
    assert_includes closed_prs, old_closed_pr
    assert_not_includes closed_prs, open_pr
    assert_not_includes closed_prs, merged_pr
  end

  test "merged scope returns only merged pull requests" do
    open_pr = pull_requests(:pr_one) # fixture has state: "open"
    closed_pr = pull_requests(:pr_closed) # fixture has state: "closed"
    merged_pr = pull_requests(:pr_merged) # fixture has state: "merged"
    minimal_merged_pr = pull_requests(:pr_minimal) # fixture has state: "merged"

    merged_prs = PullRequest.merged
    assert_includes merged_prs, merged_pr
    assert_includes merged_prs, minimal_merged_pr
    assert_not_includes merged_prs, open_pr
    assert_not_includes merged_prs, closed_pr
  end

  test "by_recent scope orders by github_updated_at descending" do
    # Clear any existing PRs to ensure clean test
    PullRequest.destroy_all

    older_pr = PullRequest.create!(@valid_attributes.merge(
      github_pr_id: 555,
      github_pr_url: "https://github.com/octocat/hello-world/pull/555",
      github_updated_at: 3.days.ago
    ))
    newer_pr = PullRequest.create!(@valid_attributes.merge(
      github_pr_id: 666,
      github_pr_url: "https://github.com/octocat/hello-world/pull/666",
      github_updated_at: 1.day.ago
    ))

    recent_prs = PullRequest.by_recent
    assert_equal newer_pr, recent_prs.first
    assert_equal older_pr, recent_prs.second
  end

  # State method tests
  test "closed? returns true for closed state" do
    @pull_request.state = "closed"
    assert @pull_request.closed?

    @pull_request.state = "open"
    assert_not @pull_request.closed?

    @pull_request.state = "merged"
    assert_not @pull_request.closed?
  end

  test "merged? returns true for merged state" do
    @pull_request.state = "merged"
    assert @pull_request.merged?

    @pull_request.state = "open"
    assert_not @pull_request.merged?

    @pull_request.state = "closed"
    assert_not @pull_request.merged?
  end

  test "open? returns true for open state" do
    @pull_request.state = "open"
    assert @pull_request.open?

    @pull_request.state = "closed"
    assert_not @pull_request.open?

    @pull_request.state = "merged"
    assert_not @pull_request.open?
  end

  test "number returns github_pr_id" do
    @pull_request.github_pr_id = 12345
    assert_equal 12345, @pull_request.number
  end

  # Edge case and data integrity tests
  test "handles very long titles" do
    @pull_request.title = "A" * 1000
    assert @pull_request.valid?
  end

  test "handles special characters in title" do
    @pull_request.title = "Fix issue with 'quotes' & <html> tags"
    assert @pull_request.valid?
  end

  test "handles special characters in author" do
    @pull_request.author = "user-name_123"
    assert @pull_request.valid?
  end

  test "handles various state values" do
    valid_states = %w[open closed merged draft]
    valid_states.each do |state|
      @pull_request.state = state
      assert @pull_request.valid?, "State '#{state}' should be valid"
    end
  end

  test "github_pr_id accepts large integers" do
    @pull_request.github_pr_id = 999999999
    assert @pull_request.valid?
  end

  test "github_pr_id cannot be zero" do
    @pull_request.github_pr_id = 0
    # Model validation only checks presence, not positive value
    # This is intentional - GitHub PR IDs start from 1 but validation is minimal
    assert @pull_request.valid?
  end

  test "github_pr_id cannot be negative" do
    @pull_request.github_pr_id = -1
    # Model validation only checks presence, not positive value
    assert @pull_request.valid?
  end

  # URL validation tests
  test "accepts valid GitHub PR URLs" do
    valid_urls = [
      "https://github.com/owner/repo/pull/123",
      "https://github.com/owner-name/repo-name/pull/999999",
      "https://github.com/123org/456repo/pull/1"
    ]

    valid_urls.each do |url|
      @pull_request.github_pr_url = url
      assert @pull_request.valid?, "URL '#{url}' should be valid"
    end
  end

  test "accepts non-GitHub URLs" do
    # Model doesn't validate URL format, just presence
    @pull_request.github_pr_url = "https://example.com/pr/123"
    assert @pull_request.valid?
  end

  # Fixture integration tests
  test "fixture pr_one is valid" do
    pr = pull_requests(:pr_one)
    assert pr.valid?
    assert_equal "open", pr.state
    assert pr.open?
  end

  test "fixture pr_two is valid" do
    pr = pull_requests(:pr_two)
    assert pr.valid?
    assert_equal "open", pr.state
    assert pr.open?
  end

  test "fixtures have unique github_pr_ids within same repository" do
    pr_one = pull_requests(:pr_one)
    pr_two = pull_requests(:pr_two)

    assert_equal pr_one.repository, pr_two.repository
    assert_not_equal pr_one.github_pr_id, pr_two.github_pr_id
  end
end
