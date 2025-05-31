# Service for syncing pull requests from external sources (GitHub, etc.)
# to the local pull_requests table for a specific repository
class PullRequestSyncer
  attr_reader :repository, :user, :data_provider

  def initialize(repository)
    @repository = repository
    @user = repository.user
    @data_provider = PullRequestDataProviderFactory.provider_for(user)
  end

  # Main sync method - fetches PRs and updates local database
  # Returns a hash with sync results
  def sync!
    Rails.logger.info "🔄 Starting PR sync for #{repository.full_name}"

    begin
      # Fetch PR data from the provider
      pr_data_list = data_provider.fetch_repository_pull_requests(repository, user)

      if pr_data_list.empty?
        Rails.logger.info "📭 No pull requests found for #{repository.full_name}"
        return { synced: 0, errors: [], status: :no_prs }
      end

      synced_count = 0
      errors = []

      # Process each pull request
      pr_data_list.each do |pr_data|
        begin
          sync_pull_request(pr_data)
          synced_count += 1
        rescue => e
          error_msg = "Failed to sync PR ##{pr_data[:github_pr_number]}: #{e.message}"
          Rails.logger.error error_msg
          errors << error_msg
        end
      end

      # Update repository's last sync time
      repository.touch(:updated_at)

      Rails.logger.info "✅ PR sync completed for #{repository.full_name}: #{synced_count} synced, #{errors.size} errors"

      {
        synced: synced_count,
        errors: errors,
        status: errors.empty? ? :success : :partial_success
      }

    rescue => e
      Rails.logger.error "❌ PR sync failed for #{repository.full_name}: #{e.message}"
      {
        synced: 0,
        errors: [ e.message ],
        status: :error
      }
    end
  end

  private

  # Sync a single pull request to the database
  def sync_pull_request(pr_data)
    pull_request = repository.pull_requests.find_or_initialize_by(
      github_pr_number: pr_data[:github_pr_number]
    )

    # Update attributes from fetched data
    pull_request.assign_attributes(
      title: pr_data[:title],
      body: pr_data[:body],
      state: pr_data[:state],
      author: pr_data[:author],
      github_url: pr_data[:github_url],
      github_created_at: pr_data[:github_created_at],
      github_updated_at: pr_data[:github_updated_at],
      last_synced_at: Time.current
    )

    # Set review_interest if it's a new record (default to medium interest)
    if pull_request.new_record?
      pull_request.review_interest = 5
    end

    unless pull_request.save
      raise "Validation failed: #{pull_request.errors.full_messages.join(', ')}"
    end

    Rails.logger.debug "✓ Synced PR ##{pr_data[:github_pr_number]}: #{pr_data[:title]}"
    pull_request
  end
end
