# Factory class to determine which data provider to use
# Based on environment configuration and user settings
class PullRequestDataProviderFactory
  def self.provider_for(user)
    # Check if we should use real GitHub data
    if should_use_github_provider?(user)
      GithubPullRequestDataProvider
    else
      DummyPullRequestDataProvider
    end
  end

  private

  def self.should_use_github_provider?(user)
    # Use GitHub provider if:
    # 1. User has GitHub token configured (prioritize user capability)
    # 2. Not explicitly forced to use dummy data via environment
    # 3. Respect user preferences over global dummy mode

    return false unless user&.respond_to?(:github_token_configured?)
    return false unless user.github_token_configured?
    return false if explicitly_dummy_mode?

    true
  end

  def self.explicitly_dummy_mode?
    # Only use dummy data if explicitly requested, not just because we're in development
    ENV["PULL_REQUEST_DATA_PROVIDER"] == "dummy" ||
    ENV["FORCE_DUMMY_DATA"] == "true"
  end

  def self.dummy_data_mode?
    # Legacy method - use explicitly_dummy_mode? instead
    explicitly_dummy_mode?
  end
end
