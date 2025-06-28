# Base class for pull request data providers
# Defines the common interface for both dummy and real data sources
class PullRequestDataProvider
  # Find or create a pull request review with repository auto-registration
  # Returns [repository, pull_request_review]
  def self.fetch_or_create_pr_review(owner:, name:, pr_number:, user:)
    raise NotImplementedError, "Subclasses must implement fetch_or_create_pr_review"
  end

  # Fetch all pull requests for a repository
  # Returns array of pull request data hashes
  def self.fetch_repository_pull_requests(repository, user)
    raise NotImplementedError, "Subclasses must implement fetch_repository_pull_requests"
  end

  # Additional methods can be added here as the interface evolves
  # def self.sync_pr_data(pull_request_review)
  #   raise NotImplementedError, "Subclasses must implement sync_pr_data"
  # end
end
