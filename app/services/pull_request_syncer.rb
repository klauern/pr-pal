# Service for syncing pull requests from external sources (GitHub, etc.)
# to the local pull_requests table for a specific repository
class PullRequestSyncer
  attr_reader :repository, :user, :data_provider

  def initialize(repository)
    @repository = repository
    @user = repository.user
    @data_provider = PullRequestDataProviderFactory.provider_for(user)
    Rails.logger.info "[PullRequestSyncer] Initialized for repository: #{@repository.full_name} (ID: #{@repository.id}), User ID: #{@user.id}, Data Provider: #{@data_provider.class.name}"
  end

  # Main sync method - fetches PRs and updates local database
  # Returns a hash with sync results
  def sync!
    Rails.logger.info "[PullRequestSyncer] 🔄 Starting PR sync for #{repository.full_name} (ID: #{repository.id})"

    begin
      # Fetch PR data from the provider
      Rails.logger.info "[PullRequestSyncer] Fetching PRs for #{@repository.full_name} (ID: #{@repository.id}) using #{@data_provider.class.name}"
      pr_data_list = data_provider.fetch_repository_pull_requests(repository, user)
      Rails.logger.info "[PullRequestSyncer] Fetched #{pr_data_list.size} PR data items for #{@repository.full_name} (ID: #{@repository.id})"

      if pr_data_list.empty?
        Rails.logger.info "[PullRequestSyncer] 📭 No pull requests found for #{repository.full_name} (ID: #{repository.id})"
        return { synced: 0, errors: [], status: :no_prs }
      end

      synced_count = 0
      errors = []

      # Process each pull request
      Rails.logger.info "[PullRequestSyncer] Starting to process #{pr_data_list.size} PR data items for #{@repository.full_name} (ID: #{@repository.id})"
      pr_data_list.each do |pr_data|
        begin
          Rails.logger.info "[PullRequestSyncer] Processing PR data: #{pr_data.inspect} for #{@repository.full_name} (ID: #{@repository.id})"
          sync_pull_request(pr_data)
          synced_count += 1
        rescue ActiveRecord::RecordInvalid => e
          error_msg = "Validation failed for PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id}): #{e.message}. Record errors: #{e.record.errors.full_messages.join(', ')}"
          Rails.logger.error "[PullRequestSyncer] #{error_msg}"
          errors << error_msg
        rescue => e
          error_msg = "Failed to sync PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id}): #{e.message}"
          Rails.logger.error "[PullRequestSyncer] #{error_msg}" # Removed backtrace for now
          errors << error_msg
        end
      end

      # Update repository's last sync time
      repository.touch(:updated_at) # This also updates last_synced_at if that's the intention, or use specific field

      Rails.logger.info "[PullRequestSyncer] ✅ PR sync completed for #{repository.full_name} (ID: #{repository.id}): #{synced_count} synced, #{errors.size} errors"

      {
        synced: synced_count,
        errors: errors,
        status: errors.empty? ? :success : :partial_success
      }

    rescue => e
      Rails.logger.error "[PullRequestSyncer] ❌ PR sync failed for #{repository.full_name} (ID: #{@repository.id}): #{e.message}" # Removed backtrace for now
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
      github_pr_id: pr_data[:github_pr_number]
    )
    Rails.logger.info "[PullRequestSyncer] Found or initialized PullRequest for GitHub PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id}). New record: #{pull_request.new_record?}"

    # Update attributes from fetched data
    pull_request.assign_attributes(
      title: pr_data[:title],
      body: pr_data[:body],
      state: pr_data[:state],
      author: pr_data[:author],
      github_pr_url: pr_data[:github_url],
      github_created_at: pr_data[:github_created_at],
      github_updated_at: pr_data[:github_updated_at],
      last_synced_at: Time.current
    )
    Rails.logger.info "[PullRequestSyncer] Assigned attributes for PullRequest GitHub PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id})"

    # Log whether this is a new or existing record
    if pull_request.new_record?
      Rails.logger.info "[PullRequestSyncer] New PullRequest record for GitHub PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id})."
    else
      Rails.logger.info "[PullRequestSyncer] Existing PullRequest record ID #{pull_request.id} for GitHub PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id})."
    end

    unless pull_request.save
      # Log detailed validation errors
      error_details = pull_request.errors.full_messages.join(", ")
      Rails.logger.error "[PullRequestSyncer] Validation failed for PullRequest GitHub PR ##{pr_data[:github_pr_number]} in repo #{@repository.full_name} (ID: #{@repository.id}): #{error_details}"
      raise "Validation failed: #{error_details}"
    end

    Rails.logger.info "[PullRequestSyncer] ✓ Successfully saved PullRequest ID #{pull_request.id} (GitHub PR ##{pr_data[:github_pr_number]}): #{pr_data[:title]} for repo #{@repository.full_name} (ID: #{@repository.id})"
    pull_request
  end
end
