# app/jobs/pull_request_sync_job.rb
class PullRequestSyncJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Fetch all users
    User.find_each do |user|
      # Fetch all repositories for the user
      user.repositories.find_each do |repository|
        # Use the data provider to sync pull requests for this repository
        # Need to implement the sync logic in the data provider or a dedicated service
        # For now, just a placeholder
        Rails.logger.info "PullRequestSyncJob: Syncing pull requests for repository: #{repository.owner}/#{repository.name} for user #{user.id}"
        PullRequestSyncer.sync_repository(repository, user)
      end
    end
  end
end
