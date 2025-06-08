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
        base_sha: pr.base.sha
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

    pull_request_review.update!(
      github_pr_title: pr_data[:title],
      last_synced_at: Time.current
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
        status: "in_progress"
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
