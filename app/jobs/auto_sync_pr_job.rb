class AutoSyncPrJob < ApplicationJob
  queue_as :default

  def perform(pull_request_review_id)
    pull_request_review = PullRequestReview.find(pull_request_review_id)
    repository = pull_request_review.repository
    user = pull_request_review.user

    Rails.logger.info "AUTO_SYNC: Starting auto sync for PR review #{pull_request_review_id}"

    # Skip if data is fresh (less than 15 minutes old)
    if pull_request_review.last_synced_at && pull_request_review.last_synced_at > 15.minutes.ago
      Rails.logger.info "AUTO_SYNC: Skipping sync - data is fresh (#{time_ago_in_words(pull_request_review.last_synced_at)} old)"
      return
    end

    # Skip if already syncing (prevent duplicate jobs)
    if pull_request_review.syncing?
      Rails.logger.info "AUTO_SYNC: Skipping sync - already in progress"
      return
    end

    begin
      # Mark as syncing
      pull_request_review.update!(sync_status: "syncing")

      provider = DataProviders.pull_request_provider
      Rails.logger.info "AUTO_SYNC: Using provider: #{provider.name}"

      if provider.name == "GithubPullRequestDataProvider"
        # For GitHub provider, fetch latest data
        pr_data = provider.fetch_pr_details(
          repository.owner,
          repository.name,
          pull_request_review.github_pr_id,
          user
        )

        pr_diff = provider.fetch_pr_diff(
          repository.owner,
          repository.name,
          pull_request_review.github_pr_id,
          user
        )

        # Update the review with latest data
        pull_request_review.update!(
          github_pr_title: pr_data[:title],
          github_pr_url: pr_data[:html_url],
          last_synced_at: Time.current,
          pr_diff: pr_diff,
          sync_status: "completed"
        )

        # Update the associated PullRequest if it exists
        if pull_request_review.pull_request
          pull_request_review.pull_request.update!(
            title: pr_data[:title],
            body: pr_data[:body],
            state: pr_data[:state],
            author: pr_data[:user],
            github_pr_url: pr_data[:html_url],
            github_updated_at: pr_data[:updated_at]
          )
        end

        Rails.logger.info "AUTO_SYNC: Successfully synced GitHub data (#{pr_diff&.length || 0} characters)"
      else
        # For dummy provider, refresh the dummy data
        pr_diff = provider.generate_dummy_pr_diff(repository, pull_request_review.github_pr_id)
        pull_request_review.update!(
          pr_diff: pr_diff,
          last_synced_at: Time.current,
          sync_status: "completed"
        )

        Rails.logger.info "AUTO_SYNC: Successfully refreshed dummy data"
      end

      # Broadcast update to any open views
      broadcast_sync_update(pull_request_review)

    rescue => e
      Rails.logger.error "AUTO_SYNC: Failed to sync PR data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      pull_request_review.update!(sync_status: "failed")

      # Re-raise for job retry logic
      raise e
    end
  end

  private

  def time_ago_in_words(time)
    distance_in_minutes = ((Time.current - time) / 60).round

    case distance_in_minutes
    when 0 then "just now"
    when 1 then "1 minute ago"
    when 2...60 then "#{distance_in_minutes} minutes ago"
    when 60...120 then "1 hour ago"
    when 120...1440 then "#{(distance_in_minutes / 60).round} hours ago"
    else "#{(distance_in_minutes / 1440).round} days ago"
    end
  end

  def broadcast_sync_update(pull_request_review)
    # Broadcast to the conversation view if it's open
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{pull_request_review.id}",
      target: "sync_status",
      partial: "pull_request_reviews/sync_status",
      locals: { pull_request_review: pull_request_review }
    )
  rescue => e
    # Don't fail the job if broadcast fails
    Rails.logger.warn "AUTO_SYNC: Failed to broadcast update: #{e.message}"
  end
end
