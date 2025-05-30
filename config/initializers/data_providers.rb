# Data provider initialization based on environment configuration
# This initializer sets up the data provider selection logic

Rails.application.config.after_initialize do
  # Log the current configuration for debugging
  use_dummy_data = Rails.application.config.x.use_dummy_data

  if use_dummy_data
    Rails.logger.info "🎭 DUMMY data mode enabled"
  else
    Rails.logger.info "🔗 GITHUB API data mode enabled"
  end

  Rails.logger.info "Data provider configuration:"
  Rails.logger.info "  Environment: #{Rails.env}"
  Rails.logger.info "  USE_DUMMY_DATA env var: #{ENV['USE_DUMMY_DATA'] || 'not set'}"
  Rails.logger.info "  Resolved use_dummy_data: #{use_dummy_data}"
end

# Helper module to get the current data provider
module DataProviders
  def self.pull_request_provider
    if Rails.application.config.x.use_dummy_data
      "DummyPullRequestDataProvider".constantize
    else
      "GithubPullRequestDataProvider".constantize
    end
  end
end
