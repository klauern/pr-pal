# app/services/pull_request_syncer.rb
class PullRequestSyncer
  def self.sync_repository(repository, user)
    # Get the appropriate data provider based on the environment/configuration
    data_provider = PullRequestDataProvider.provider_for(user)

    Rails.logger.info "PullRequestSyncer: Syncing repository #{repository.owner}/#{repository.name} for user #{user.id}"

    begin
      # Fetch open pull requests from the data provider
      pr_data_list = data_provider.fetch_open_pull_requests(repository, user)

      # Process fetched PR data
      pr_data_list.each do |pr_data|
        # Find or initialize PullRequestReview based on GitHub PR ID and repository
        pr_review = user.pull_request_reviews.find_or_initialize_by(
          github_pr_id: pr_data[:id],
          repository: repository
        )

        # Update attributes
        pr_review.assign_attributes(
          github_pr_title: pr_data[:title],
          github_pr_url: pr_data[:html_url],
          status: pr_data[:state], # Use GitHub PR state as status initially
          last_synced_at: Time.current,
          ci_status: pr_data[:ci_status], # Add CI status
          ci_url: pr_data[:ci_url], # Add CI URL
          github_comment_count: pr_data[:comment_count], # Add comment count
          github_review_status: pr_data[:review_status], # Add review status
          # TODO: Add more attributes as needed
        )

        # Save if changes were made
        if pr_review.changed?
          pr_review.save!
          Rails.logger.info "PullRequestSyncer: Updated/Created PR Review #{pr_review.id} for PR ##{pr_data[:number]}"
        end
      end

      # Handle PRs that are no longer open (e.g., closed or merged)
      # Fetch all current open PR IDs from the fetched data
      current_open_pr_ids = pr_data_list.map { |pr_data| pr_data[:id] }

      # Find PR reviews in the database for this repository that are marked as 'open' but are not in the current open list
      pull_request_reviews_to_close = user.pull_request_reviews.where(repository: repository, status: "open")
                                                              .where.not(github_pr_id: current_open_pr_ids)

      # Update their status to 'closed'
      pull_request_reviews_to_close.each do |pr_review|
        pr_review.update!(status: "closed", last_synced_at: Time.current)
        Rails.logger.info "PullRequestSyncer: Marked PR Review #{pr_review.id} as closed for PR ##{pr_review.github_pr_id}"
      end

    rescue GithubPullRequestDataProvider::GitHubError => e
      Rails.logger.error "PullRequestSyncer: Error syncing repository #{repository.owner}/#{repository.name}: #{e.message}"
      # TODO: Implement more sophisticated error handling (e.g., notify user)
    rescue StandardError => e
      Rails.logger.error "PullRequestSyncer: Unexpected error syncing repository #{repository.owner}/#{repository.name}: #{e.message}"
      # TODO: Implement more sophisticated error handling
    end
  end
end
