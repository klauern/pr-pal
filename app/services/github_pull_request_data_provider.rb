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

        pull_request_review.assign_attributes(
          github_pr_title: pr_data[:title],
          github_pr_url: pr_data[:html_url],
          status: "in_progress",
          last_synced_at: Time.current
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

  # Determine a simplified review status based on requested reviewers and PR state
  def self.determine_review_status(requested_reviewers, pr_state)
    if pr_state == "closed" || pr_state == "merged"
      pr_state
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
end
