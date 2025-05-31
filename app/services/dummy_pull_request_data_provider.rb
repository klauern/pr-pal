# Dummy data provider - wraps existing auto-creation logic
# Creates repositories and PR reviews with realistic dummy data
class DummyPullRequestDataProvider < PullRequestDataProvider
  def self.fetch_or_create_pr_review(owner:, name:, pr_number:, user:)
    # Find or create repository (same as existing logic)
    repository = user.repositories.find_or_create_by(
      owner: owner,
      name: name
    )

    # Find or create pull request review with proper repository association
    pull_request_review = user.pull_request_reviews.find_or_initialize_by(
      github_pr_id: pr_number,
      repository: repository
    )

    # If this is a new review, set default values with dummy data
    if pull_request_review.new_record?
      pull_request_review.assign_attributes(
        github_pr_title: generate_dummy_pr_title(repository, pr_number),
        github_pr_url: "#{repository.github_url}/pull/#{pr_number}",
        status: "in_progress"
      )

      unless pull_request_review.save
        raise "Failed to create review: #{pull_request_review.errors.full_messages.join(', ')}"
      end
    end

    [ repository, pull_request_review ]
  end

  private

  def self.generate_dummy_pr_title(repository, pr_number)
    # Generate more realistic dummy PR titles
    dummy_titles = [
      "Fix authentication bug in user sessions",
      "Add responsive design for mobile devices",
      "Implement caching for improved performance",
      "Update dependencies and security patches",
      "Refactor user profile component",
      "Add integration tests for API endpoints",
      "Improve error handling in payment flow",
      "Update documentation and README",
      "Fix memory leak in background jobs",
      "Add feature flags for A/B testing"
    ]

    base_title = dummy_titles.sample
    "#{base_title} (##{pr_number})"
  end

  # Fetch all pull requests for a repository (dummy data)
  def self.fetch_repository_pull_requests(repository, user)
    # Generate some dummy pull requests
    pr_count = rand(3..8)

    (1..pr_count).map do |i|
      pr_number = i + rand(10..100)
      state = [ "open", "open", "open", "closed", "merged" ].sample # More open PRs

      {
        github_pr_number: pr_number,
        title: generate_dummy_pr_title(repository, pr_number).gsub(" (##{pr_number})", ""),
        body: "This is a dummy pull request for testing purposes. Repository: #{repository.full_name}",
        state: state,
        author: [ "developer1", "codereviewer", "teamlead", "contributor" ].sample,
        github_url: "#{repository.github_url}/pull/#{pr_number}",
        github_created_at: rand(30.days).seconds.ago,
        github_updated_at: rand(7.days).seconds.ago
      }
    end
  end
end
