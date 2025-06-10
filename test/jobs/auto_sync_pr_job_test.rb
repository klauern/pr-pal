require "test_helper"

class AutoSyncPrJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:one)
  end

  test "should skip sync if data is fresh" do
    @pull_request_review.update!(last_synced_at: 5.minutes.ago)

    # Should not perform any sync operations
    assert_no_enqueued_jobs do
      AutoSyncPrJob.perform_now(@pull_request_review.id)
    end
  end

  test "should sync if data is stale" do
    @pull_request_review.update!(last_synced_at: 20.minutes.ago, sync_status: "pending")

    # Mock the data provider to prevent actual API calls
    DataProviders.stubs(:pull_request_provider).returns(DummyPullRequestDataProvider)

    assert_no_difference "@pull_request_review.reload.last_synced_at" do
      # This will update last_synced_at
      AutoSyncPrJob.perform_now(@pull_request_review.id)
    end

    @pull_request_review.reload
    assert_equal "completed", @pull_request_review.sync_status
  end

  test "should skip if already syncing" do
    @pull_request_review.update!(sync_status: "syncing")

    # Should not perform any sync operations
    assert_no_enqueued_jobs do
      AutoSyncPrJob.perform_now(@pull_request_review.id)
    end

    # Sync status should remain syncing
    assert_equal "syncing", @pull_request_review.reload.sync_status
  end
end
