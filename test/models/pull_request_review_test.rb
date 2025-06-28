require "test_helper"

class PullRequestReviewTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request = pull_requests(:pr_one)
    @valid_attributes = {
      user: @user,
      repository: @repository,
      pull_request: @pull_request,
      github_pr_id: 12345, # Use a unique ID not in fixtures
      github_pr_url: "https://github.com/octocat/hello-world/pull/12345",
      github_pr_title: "Test PR Review",
      status: "in_progress"
    }
    @review = PullRequestReview.new(@valid_attributes)
  end

  # Association tests
  test "belongs to user" do
    assert_respond_to @review, :user
    assert_instance_of User, @review.user
  end

  test "belongs to repository" do
    assert_respond_to @review, :repository
    assert_instance_of Repository, @review.repository
  end

  test "belongs to pull request" do
    assert_respond_to @review, :pull_request
    assert_instance_of PullRequest, @review.pull_request
  end

  test "has many llm conversation messages" do
    assert_respond_to @review, :llm_conversation_messages
  end

  test "dependent destroy for llm conversation messages" do
    @review.save!
    message = @review.llm_conversation_messages.create!(
      sender: "user",
      content: "Test message",
      order: 1
    )

    assert_difference "LlmConversationMessage.count", -1 do
      @review.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @review.valid?
  end

  test "should require github_pr_id" do
    @review.github_pr_id = nil
    assert_not @review.valid?
    assert_includes @review.errors[:github_pr_id], "can't be blank"
  end

  test "should require github_pr_url" do
    @review.github_pr_url = nil
    assert_not @review.valid?
    assert_includes @review.errors[:github_pr_url], "can't be blank"

    @review.github_pr_url = ""
    assert_not @review.valid?
    assert_includes @review.errors[:github_pr_url], "can't be blank"
  end

  test "should require github_pr_title" do
    @review.github_pr_title = nil
    assert_not @review.valid?
    assert_includes @review.errors[:github_pr_title], "can't be blank"

    @review.github_pr_title = ""
    assert_not @review.valid?
    assert_includes @review.errors[:github_pr_title], "can't be blank"
  end

  test "should require status" do
    @review.status = nil
    assert_not @review.valid?
    assert_includes @review.errors[:status], "can't be blank"

    @review.status = ""
    assert_not @review.valid?
    assert_includes @review.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    valid_statuses = %w[in_progress completed archived]
    valid_statuses.each do |status|
      @review.status = status
      assert @review.valid?, "Status '#{status}' should be valid"
    end

    invalid_statuses = %w[pending draft cancelled unknown]
    invalid_statuses.each do |status|
      @review.status = status
      assert_not @review.valid?, "Status '#{status}' should be invalid"
      assert_includes @review.errors[:status], "is not included in the list"
    end
  end

  test "should require unique github_pr_id scoped to repository" do
    @review.save!

    duplicate_review = PullRequestReview.new(@valid_attributes)
    assert_not duplicate_review.valid?
    assert_includes duplicate_review.errors[:github_pr_id], "has already been taken"
  end

  test "should allow same github_pr_id for different repositories" do
    @review.save!

    other_repo = repositories(:two)
    other_user = users(:two)
    other_pr = PullRequest.create!(
      repository: other_repo,
      github_pr_id: 888,
      github_pr_url: "https://github.com/github/docs/pull/888",
      title: "Other PR",
      state: "open",
      author: "other_author"
    )

    other_review = PullRequestReview.new(@valid_attributes.merge(
      repository: other_repo,
      user: other_user,
      pull_request: other_pr
    ))
    assert other_review.valid?
  end

  # Scope tests
  test "in_progress scope returns only in_progress reviews" do
    in_progress_review = pull_request_reviews(:review_pr_one) # fixture has status: "in_progress"
    completed_review = pull_request_reviews(:review_pr_two)   # fixture has status: "completed"

    in_progress_reviews = PullRequestReview.in_progress
    assert_includes in_progress_reviews, in_progress_review
    assert_not_includes in_progress_reviews, completed_review
  end

  test "completed scope returns only completed reviews" do
    in_progress_review = pull_request_reviews(:review_pr_one) # fixture has status: "in_progress"
    completed_review = pull_request_reviews(:review_pr_two)   # fixture has status: "completed"

    completed_reviews = PullRequestReview.completed
    assert_includes completed_reviews, completed_review
    assert_not_includes completed_reviews, in_progress_review
  end

  # Method tests
  test "mark_as_completed! updates status to completed" do
    @review.status = "in_progress"
    @review.save!

    @review.mark_as_completed!
    assert_equal "completed", @review.status
    assert_equal "completed", @review.reload.status
  end

  test "mark_as_viewed! updates last_viewed_at timestamp" do
    @review.save!
    original_time = @review.last_viewed_at

    travel_to 1.hour.from_now do
      @review.mark_as_viewed!
      assert_not_equal original_time, @review.last_viewed_at
      assert_in_delta Time.current, @review.last_viewed_at, 1.second
    end
  end

  test "total_message_count returns correct count" do
    @review.save!
    assert_equal 0, @review.total_message_count

    3.times do |i|
      @review.llm_conversation_messages.create!(
        sender: "user",
        content: "Message #{i}",
        order: i + 1
      )
    end

    assert_equal 3, @review.total_message_count
  end

  test "last_message returns most recent message by order" do
    @review.save!

    first_message = @review.llm_conversation_messages.create!(
      sender: "user",
      content: "First message",
      order: 1
    )

    last_message = @review.llm_conversation_messages.create!(
      sender: "llm",
      content: "Last message",
      order: 2
    )

    assert_equal last_message, @review.last_message
  end

  test "last_message returns nil when no messages exist" do
    @review.save!
    assert_nil @review.last_message
  end

  # Sync status tests
  test "stale_data? returns true when last_synced_at is nil" do
    @review.last_synced_at = nil
    assert @review.stale_data?
  end

  test "stale_data? returns true when last_synced_at is older than 1 hour" do
    @review.last_synced_at = 2.hours.ago
    assert @review.stale_data?
  end

  test "stale_data? returns false when last_synced_at is within 1 hour" do
    @review.last_synced_at = 30.minutes.ago
    assert_not @review.stale_data?
  end

  test "needs_auto_sync? returns false when syncing" do
    @review.sync_status = "syncing"
    assert_not @review.needs_auto_sync?
  end

  test "needs_auto_sync? returns true when last_synced_at is nil" do
    @review.sync_status = "completed"
    @review.last_synced_at = nil
    assert @review.needs_auto_sync?
  end

  test "needs_auto_sync? returns true when last_synced_at is older than 15 minutes" do
    @review.sync_status = "completed"
    @review.last_synced_at = 20.minutes.ago
    assert @review.needs_auto_sync?
  end

  test "needs_auto_sync? returns false when last_synced_at is within 15 minutes" do
    @review.sync_status = "completed"
    @review.last_synced_at = 10.minutes.ago
    assert_not @review.needs_auto_sync?
  end

  test "syncing? returns true when sync_status is syncing" do
    @review.sync_status = "syncing"
    assert @review.syncing?

    @review.sync_status = "completed"
    assert_not @review.syncing?
  end

  test "sync_completed? returns true when sync_status is completed" do
    @review.sync_status = "completed"
    assert @review.sync_completed?

    @review.sync_status = "syncing"
    assert_not @review.sync_completed?
  end

  test "sync_failed? returns true when sync_status is failed" do
    @review.sync_status = "failed"
    assert @review.sync_failed?

    @review.sync_status = "completed"
    assert_not @review.sync_failed?
  end

  # Edge case and data integrity tests
  test "handles very long github_pr_title" do
    @review.github_pr_title = "A" * 1000
    assert @review.valid?
  end

  test "handles special characters in github_pr_title" do
    @review.github_pr_title = "Fix issue with 'quotes' & <html> tags"
    assert @review.valid?
  end

  test "handles various github_pr_url formats" do
    valid_urls = [
      "https://github.com/owner/repo/pull/123",
      "https://github.com/owner-name/repo-name/pull/999999",
      "https://github.com/123org/456repo/pull/1"
    ]

    valid_urls.each do |url|
      @review.github_pr_url = url
      assert @review.valid?, "URL '#{url}' should be valid"
    end
  end

  test "github_pr_id accepts large integers" do
    @review.github_pr_id = 999999999
    assert @review.valid?
  end

  test "handles missing optional fields gracefully" do
    @review.llm_context_summary = nil
    @review.last_viewed_at = nil
    @review.sync_status = nil
    @review.last_synced_at = nil
    assert @review.valid?
  end

  # Fixture integration tests
  test "fixture one is valid and in_progress" do
    review = pull_request_reviews(:review_pr_one)
    assert review.valid?
    assert_equal "in_progress", review.status
  end

  test "fixture two is valid and completed" do
    review = pull_request_reviews(:review_pr_two)
    assert review.valid?
    assert_equal "completed", review.status
  end

  test "fixtures have unique github_pr_ids within same repository" do
    review_one = pull_request_reviews(:review_pr_one)
    review_two = pull_request_reviews(:review_pr_two)

    assert_equal review_one.repository, review_two.repository
    assert_not_equal review_one.github_pr_id, review_two.github_pr_id
  end

  test "fixtures have associated conversation messages" do
    review = pull_request_reviews(:review_pr_one)
    messages = review.llm_conversation_messages

    assert messages.any?, "Review should have conversation messages"
    assert_equal 3, messages.count

    # Test ordering
    ordered_messages = messages.ordered
    assert_equal 1, ordered_messages.first.order
    assert_equal 3, ordered_messages.last.order
  end

  # Integration tests with conversation messages
  test "creating messages updates total_message_count" do
    @review.save!

    assert_equal 0, @review.total_message_count

    @review.llm_conversation_messages.create!(
      sender: "user",
      content: "Hello",
      order: 1
    )

    # Reload to get fresh count
    @review.reload
    assert_equal 1, @review.total_message_count
  end

  test "deleting review cascades to messages" do
    review = pull_request_reviews(:review_pr_one)
    message_count = review.llm_conversation_messages.count

    assert message_count > 0, "Fixture should have messages"

    assert_difference "LlmConversationMessage.count", -message_count do
      review.destroy
    end
  end
end
