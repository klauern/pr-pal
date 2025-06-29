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

    # Fetch and store CI/CD status
    begin
      ci_status_data = nil
      ci_status = nil
      if data_provider.respond_to?(:fetch_pr_ci_statuses)
        ci_status_data = data_provider.fetch_pr_ci_statuses(
          repository.owner,
          repository.name,
          pr_data[:github_pr_number],
          user
        )
        # Determine overall status: prefer check_runs, fallback to combined status
        if ci_status_data[:check_runs]&.any?
          # Use the worst status: failure > pending (in_progress) > success
          conclusions = ci_status_data[:check_runs].map { |run| run[:conclusion] }.compact
          statuses = ci_status_data[:check_runs].map { |run| run[:status] }.compact
          if conclusions.include?("failure") || conclusions.include?("cancelled") || conclusions.include?("timed_out")
            ci_status = "failure"
          elsif statuses.include?("in_progress")
            ci_status = "pending"
          elsif conclusions.include?("pending")
            ci_status = "pending"
          elsif conclusions.include?("success")
            ci_status = "success"
          else
            ci_status = "unknown"
          end
        elsif ci_status_data[:statuses]&.any?
          # Use the worst status: failure > pending > success
          states = ci_status_data[:statuses].map { |s| s[:state] }
          if states.include?("failure")
            ci_status = "failure"
          elsif states.include?("pending")
            ci_status = "pending"
          elsif states.include?("success")
            ci_status = "success"
          else
            ci_status = "unknown"
          end
        else
          ci_status = "none"
        end
        pull_request.ci_status = ci_status
        pull_request.ci_status_raw = ci_status_data.to_json
        pull_request.ci_status_updated_at = Time.current
      end
    rescue => e
      Rails.logger.warn "[PullRequestSyncer] Failed to fetch/store CI/CD status for PR ##{pr_data[:github_pr_number]}: #{e.message}"
    end

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
