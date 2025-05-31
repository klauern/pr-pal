class PullRequestSyncJob < ApplicationJob
  queue_as :default

  # Sync pull requests for a specific repository
  def perform(repository_id)
    repository = Repository.find(repository_id)
    Rails.logger.info "🚀 Starting PR sync job for repository: #{repository.full_name}"

    syncer = PullRequestSyncer.new(repository)
    result = syncer.sync!

    case result[:status]
    when :success
      Rails.logger.info "✅ PR sync job completed successfully for #{repository.full_name}: #{result[:synced]} PRs synced"
    when :partial_success
      Rails.logger.warn "⚠️ PR sync job completed with errors for #{repository.full_name}: #{result[:synced]} PRs synced, #{result[:errors].size} errors"
    when :no_prs
      Rails.logger.info "📭 No PRs found for #{repository.full_name}"
    when :error
      Rails.logger.error "❌ PR sync job failed for #{repository.full_name}: #{result[:errors].join(', ')}"
    end

    result
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ Repository with ID #{repository_id} not found"
    { synced: 0, errors: [ "Repository not found" ], status: :error }
  rescue => e
    Rails.logger.error "❌ PR sync job crashed for repository ID #{repository_id}: #{e.message}"
    { synced: 0, errors: [ e.message ], status: :error }
  end

  # Sync pull requests for all repositories of a user
  def self.sync_user_repositories(user)
    Rails.logger.info "🚀 Starting PR sync for all repositories of user: #{user.email_address}"

    results = []
    user.repositories.find_each do |repository|
      begin
        job_result = perform_now(repository.id)
        results << { repository: repository.full_name, result: job_result }
      rescue => e
        Rails.logger.error "❌ Failed to sync repository #{repository.full_name}: #{e.message}"
        results << { repository: repository.full_name, result: { synced: 0, errors: [ e.message ], status: :error } }
      end
    end

    Rails.logger.info "✅ Completed PR sync for user #{user.email_address}: #{results.size} repositories processed"
    results
  end

  # Sync pull requests for all repositories in the system (admin use)
  def self.sync_all_repositories
    Rails.logger.info "🚀 Starting system-wide PR sync for all repositories"

    total_repos = Repository.count
    processed = 0
    errors = 0

    Repository.find_each do |repository|
      begin
        perform_later(repository.id)
        processed += 1
      rescue => e
        Rails.logger.error "❌ Failed to queue sync for repository #{repository.full_name}: #{e.message}"
        errors += 1
      end
    end

    Rails.logger.info "✅ Queued PR sync jobs for #{processed}/#{total_repos} repositories (#{errors} errors)"
    { total: total_repos, queued: processed, errors: errors }
  end
end
