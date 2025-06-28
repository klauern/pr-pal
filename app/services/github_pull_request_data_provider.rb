# GitHub API data provider - fetches real data from GitHub API using Octokit
class GithubPullRequestDataProvider < PullRequestDataProvider
  class GitHubError < StandardError; end
  class AuthenticationError < GitHubError; end
  class NotFoundError < GitHubError; end
  class RateLimitError < GitHubError; end

  def self.fetch_or_create_pr_review(owner:, name:, pr_number:, user:)
    Rails.logger.info "🔗 GitHub API provider: fetching PR #{owner}/#{name}##{pr_number}"

    # Check if user has GitHub token configured
    unless user.github_token_configured?
      Rails.logger.warn "User #{user.id} has no GitHub token configured, falling back to basic creation"
      return create_basic_pr_review(owner: owner, name: name, pr_number: pr_number, user: user)
    end

    # Find or create repository
    repository = user.repositories.find_or_create_by(
      owner: owner,
      name: name
    )

    # Find or create pull request review
    pull_request_review = repository.pull_request_reviews.find_or_initialize_by(
      github_pr_id: pr_number,
      user: user
    )

    # If this is a new review or needs updating, fetch from GitHub
    if pull_request_review.new_record? || should_sync_pr_data?(pull_request_review)
      begin
        pr_data = fetch_pr_details(owner, name, pr_number, user)
        pr_diff = fetch_pr_diff(owner, name, pr_number, user)

        # Find or create the PullRequest record
        pull_request = repository.pull_requests.find_or_create_by!(
          github_pr_id: pr_number
        ) do |pr|
          pr.title = pr_data[:title]
          pr.body = pr_data[:body]
          pr.state = pr_data[:state]
          pr.author = pr_data[:user]
          pr.github_pr_url = pr_data[:html_url]
          pr.github_created_at = pr_data[:created_at]
          pr.github_updated_at = pr_data[:updated_at]
        end

        pull_request_review.assign_attributes(
          github_pr_title: pr_data[:title],
          github_pr_url: pr_data[:html_url],
          status: "in_progress",
          last_synced_at: Time.current,
          pull_request: pull_request,
          pr_diff: pr_diff
        )

        unless pull_request_review.save
          raise "Failed to create/update review: #{pull_request_review.errors.full_messages.join(', ')}"
        end

        Rails.logger.info "✅ Successfully synced PR data from GitHub API"
      rescue GitHubError => e
        Rails.logger.error "GitHub API error: #{e.message}"
        # Fall back to basic creation if GitHub API fails
        return create_basic_pr_review(owner: owner, name: name, pr_number: pr_number, user: user) if pull_request_review.new_record?
      end
    end

    [ repository, pull_request_review ]
  end

  # Fetch PR details from GitHub API
  def self.fetch_pr_details(owner, repo, pr_number, user)
    client = github_client(user)
    repo_full_name = "#{owner}/#{repo}"

    begin
      pr = client.pull_request(repo_full_name, pr_number)

      {
        title: pr.title,
        body: pr.body,
        html_url: pr.html_url,
        state: pr.state,
        created_at: pr.created_at,
        updated_at: pr.updated_at,
        merged_at: pr.merged_at,
        user: pr.user.login,
        head_sha: pr.head.sha,
        base_sha: pr.base.sha,
        # Fetch comments and reviews count
        comment_count: pr.comments,
        review_comment_count: pr.review_comments,
        # Determine review status (simplified for now)
        review_status: determine_review_status(pr.requested_reviewers, pr.state)
      }
    rescue Octokit::NotFound
      raise NotFoundError, "Pull request #{repo_full_name}##{pr_number} not found"
    rescue Octokit::Unauthorized, Octokit::Forbidden
      raise AuthenticationError, "Invalid GitHub token or insufficient permissions"
    rescue Octokit::TooManyRequests
      raise RateLimitError, "GitHub API rate limit exceeded"
    rescue Octokit::Error => e
      raise GitHubError, "GitHub API error: #{e.message}"
    end
  end

  # Determine a simplified review status based on requested reviewers, PR state, and merged_at field
  def self.determine_review_status(requested_reviewers, pr_state, merged_at)
    if !merged_at.nil?
      "merged"
    elsif pr_state == "closed"
      "closed"
    elsif requested_reviewers.any?
      "review_requested"
    else
      "no_review_requested"
    end
  end

  # Fetch combined CI status for a commit SHA
  def self.fetch_combined_status(owner, repo, commit_sha, user)
    Rails.logger.info "🔗 GitHub API provider: fetching combined status for #{owner}/#{repo}@#{commit_sha}"
    client = github_client(user)
    repo_full_name = "#{owner}/#{repo}"

    begin
      status = client.combined_status(repo_full_name, commit_sha)
      {
        state: status.state, # e.g., 'success', 'failure', 'pending', 'error'
        url: status.url # URL to the status page (e.g., CI build page)
      }
    rescue Octokit::NotFound
      Rails.logger.warn "Combined status not found for commit #{commit_sha} in #{repo_full_name}."
      { state: "unknown", url: nil } # Return unknown status if not found
    rescue Octokit::Unauthorized, Octokit::Forbidden
      raise AuthenticationError, "Invalid GitHub token or insufficient permissions to fetch status for #{repo_full_name}"
    rescue Octokit::TooManyRequests
      raise RateLimitError, "GitHub API rate limit exceeded fetching status for #{repo_full_name}"
    rescue Octokit::Error => e
      raise GitHubError, "GitHub API error fetching status for #{repo_full_name}: #{e.message}"
    end
  end

  # Fetch all open pull requests for a repository from GitHub API
  def self.fetch_open_pull_requests(repository, user)
    Rails.logger.info "🔗 GitHub API provider: fetching open PRs for #{repository.full_name}"
    client = github_client(user)

    begin
      prs = client.pull_requests(repository.full_name, state: "open")
      prs.map do |pr|
        # Fetch combined status for the head commit of the PR
        status_data = fetch_combined_status(repository.owner, repository.name, pr.head.sha, user)

        {
          id: pr.id, # Use GitHub's internal ID for uniqueness
          title: pr.title,
          body: pr.body,
          html_url: pr.html_url,
          state: pr.state,
          created_at: pr.created_at,
          updated_at: pr.updated_at,
          merged_at: pr.merged_at,
          user: pr.user.login,
          head_sha: pr.head.sha,
          base_sha: pr.base.sha,
          number: pr.number, # Include PR number for linking/display
          ci_status: status_data[:state], # Add CI status
          ci_url: status_data[:url], # Add CI URL
          comment_count: pr.comments, # Add comment count
          review_comment_count: pr.review_comments, # Add review comment count
          review_status: determine_review_status(pr.requested_reviewers, pr.state) # Add review status
        }
      end
    rescue Octokit::NotFound
      Rails.logger.warn "Repository #{repository.full_name} not found on GitHub."
      [] # Return empty array if repo not found
    rescue Octokit::Unauthorized, Octokit::Forbidden
      raise AuthenticationError, "Invalid GitHub token or insufficient permissions for #{repository.full_name}"
    rescue Octokit::TooManyRequests
      raise RateLimitError, "GitHub API rate limit exceeded for #{repository.full_name}"
    rescue Octokit::Error => e
      raise GitHubError, "GitHub API error fetching open PRs for #{repository.full_name}: #{e.message}"
    end
  end

  # Sync existing PR with latest GitHub data
  def self.sync_pr_data(pull_request_review)
    return unless pull_request_review.user.github_token_configured?

    repository = pull_request_review.repository
    pr_data = fetch_pr_details(
      repository.owner,
      repository.name,
      pull_request_review.github_pr_id,
      pull_request_review.user
    )

    # Fetch combined status for the head commit
    status_data = fetch_combined_status(repository.owner, repository.name, pr_data[:head_sha], pull_request_review.user)

    pull_request_review.update!(
      github_pr_title: pr_data[:title],
      last_synced_at: Time.current,
      ci_status: status_data[:state], # Update CI status
      ci_url: status_data[:url], # Update CI URL
      github_comment_count: pr_data[:comment_count], # Update comment count
      github_review_status: pr_data[:review_status] # Update review status
    )
  end

  # Fetch CI/CD status checks for a PR (by head SHA)
  def self.fetch_pr_ci_statuses(owner, repo, pr_number, user)
    client = github_client(user)
    repo_full_name = "#{owner}/#{repo}"

    begin
      pr = client.pull_request(repo_full_name, pr_number)
      sha = pr.head.sha

      # Fetch combined status (legacy status API)
      combined_status = client.combined_status(repo_full_name, sha)
      statuses = combined_status.statuses.map do |status|
        {
          type: :status,
          context: status.context,
          state: status.state, # success, failure, pending
          description: status.description,
          target_url: status.target_url
        }
      end

      # Fetch check runs (GitHub Actions, etc.)
      check_runs_resp = client.check_runs_for_ref(repo_full_name, sha)
      check_runs = check_runs_resp.check_runs.map do |run|
        {
          type: :check_run,
          name: run.name,
          status: run.status, # queued, in_progress, completed
          conclusion: run.conclusion, # success, failure, etc.
          details_url: run.details_url,
          output_title: run.output&.title,
          output_summary: run.output&.summary
        }
      end

      {
        sha: sha,
        statuses: statuses,
        check_runs: check_runs
      }
    rescue Octokit::NotFound
      raise NotFoundError, "PR or commit not found for CI status checks"
    rescue Octokit::Unauthorized, Octokit::Forbidden
      raise AuthenticationError, "Invalid GitHub token or insufficient permissions for CI status checks"
    rescue Octokit::TooManyRequests
      raise RateLimitError, "GitHub API rate limit exceeded for CI status checks"
    rescue Octokit::Error => e
      raise GitHubError, "GitHub API error (CI status checks): #{e.message}"
    end
  end

  def self.fetch_pr_diff(owner, repo, pr_number, user)
    client = github_client(user)

    # Try fetching the diff with retry logic
    retries = 0
    max_retries = 2

    begin
      Rails.logger.info "Fetching PR diff for #{owner}/#{repo}##{pr_number} (attempt #{retries + 1})"

      diff_content = client.pull_request("#{owner}/#{repo}", pr_number, { accept: "application/vnd.github.v3.diff" })

      if diff_content.nil? || diff_content.empty?
        Rails.logger.warn "Empty diff returned for #{owner}/#{repo}##{pr_number}"
        return generate_fallback_diff_message(owner, repo, pr_number)
      end

      Rails.logger.info "Successfully fetched PR diff (#{diff_content.length} characters)"
      diff_content

    rescue Octokit::NotFound
      Rails.logger.warn "PR #{owner}/#{repo}##{pr_number} not found for diff fetch"
      generate_fallback_diff_message(owner, repo, pr_number, "Pull request not found")
    rescue Octokit::Unauthorized, Octokit::Forbidden
      Rails.logger.warn "Unauthorized access to PR diff #{owner}/#{repo}##{pr_number}"
      generate_fallback_diff_message(owner, repo, pr_number, "Access denied - check GitHub token permissions")
    rescue Octokit::TooManyRequests
      if retries < max_retries
        retries += 1
        sleep_time = 2 ** retries # Exponential backoff
        Rails.logger.warn "Rate limited fetching PR diff, retrying in #{sleep_time}s (attempt #{retries}/#{max_retries})"
        sleep(sleep_time)
        retry
      else
        Rails.logger.error "Rate limit exceeded for PR diff after #{max_retries} retries"
        generate_fallback_diff_message(owner, repo, pr_number, "GitHub API rate limit exceeded")
      end
    rescue Octokit::Error => e
      if retries < max_retries
        retries += 1
        Rails.logger.warn "GitHub API error fetching PR diff, retrying: #{e.message} (attempt #{retries}/#{max_retries})"
        sleep(1)
        retry
      else
        Rails.logger.error "Failed to fetch PR diff after #{max_retries} retries: #{e.message}"
        generate_fallback_diff_message(owner, repo, pr_number, "GitHub API error: #{e.message}")
      end
    rescue => e
      Rails.logger.error "Unexpected error fetching PR diff: #{e.message}"
      generate_fallback_diff_message(owner, repo, pr_number, "Unexpected error")
    end
  end

  def self.generate_fallback_diff_message(owner, repo, pr_number, reason = "Unknown error")
    <<~FALLBACK
      # PR Diff Unavailable

      **Repository:** #{owner}/#{repo}
      **Pull Request:** ##{pr_number}
      **Reason:** #{reason}

      The diff for this pull request could not be retrieved from GitHub.
      You can view it directly at: https://github.com/#{owner}/#{repo}/pull/#{pr_number}

      Please ask me questions about the pull request and I'll do my best to help
      based on the context you provide in your messages.
    FALLBACK
  end

  private

  # Create basic PR review without GitHub API (fallback)
  def self.create_basic_pr_review(owner:, name:, pr_number:, user:)
    repository = user.repositories.find_or_create_by(
      owner: owner,
      name: name
    )

    pull_request_review = repository.pull_request_reviews.find_or_initialize_by(
      github_pr_id: pr_number,
      user: user
    )

    if pull_request_review.new_record?
      pull_request_review.assign_attributes(
        github_pr_title: "PR ##{pr_number} in #{repository.full_name} (GitHub API not configured)",
        github_pr_url: "#{repository.github_url}/pull/#{pr_number}",
        status: "in_progress",
        ci_status: "unknown", # Default CI status for basic creation
        github_comment_count: 0, # Default comment count
        github_review_status: "unknown" # Default review status
      )

      unless pull_request_review.save
        raise "Failed to create review: #{pull_request_review.errors.full_messages.join(', ')}"
      end
    end

    [ repository, pull_request_review ]
  end

  # Check if PR data should be synced (older than 15 minutes)
  def self.should_sync_pr_data?(pull_request_review)
    return true unless pull_request_review.respond_to?(:last_synced_at)
    return true if pull_request_review.last_synced_at.nil?

    pull_request_review.last_synced_at < 15.minutes.ago
  end

  # Initialize GitHub API client with user's token
  def self.github_client(user)
    unless user.github_token_configured?
      raise AuthenticationError, "No GitHub token configured for user"
    end

    Octokit::Client.new(
      access_token: user.github_token,
      auto_paginate: true,
      per_page: 100
    )
  end

  # Fetch all pull requests for a repository
  def self.fetch_repository_pull_requests(repository, user)
    return [] unless user.github_token_configured?

    begin
      client = github_client(user)
      repo_full_name = repository.full_name

      Rails.logger.info "🔗 Fetching PRs for #{repo_full_name}"

      # Fetch open PRs
      prs = client.pull_requests(repo_full_name, state: "open")

      # Also fetch recently closed/merged PRs (last 30 days)
      closed_prs = client.pull_requests(repo_full_name, state: "closed", sort: "updated", direction: "desc")
      recent_closed = closed_prs.select { |pr| pr.updated_at > 30.days.ago }

      all_prs = prs + recent_closed

      # Convert to our format
      all_prs.map do |pr|
        {
          github_pr_number: pr.number,
          title: pr.title,
          body: pr.body,
          state: pr.state,
          author: pr.user.login,
          github_url: pr.html_url,
          github_created_at: pr.created_at,
          github_updated_at: pr.updated_at
        }
      end
    rescue Octokit::NotFound
      Rails.logger.warn "Repository #{repo_full_name} not found"
      []
    rescue Octokit::Unauthorized, Octokit::Forbidden
      Rails.logger.warn "Unauthorized access to #{repo_full_name}"
      []
    rescue Octokit::TooManyRequests
      Rails.logger.warn "Rate limit exceeded for #{repo_full_name}"
      []
    rescue Octokit::Error => e
      Rails.logger.error "GitHub API error for #{repo_full_name}: #{e.message}"
      []
    end
  end
end
