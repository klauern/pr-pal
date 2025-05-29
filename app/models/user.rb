class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :repositories, dependent: :destroy
  has_many :pull_request_reviews, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Encrypt GitHub token for security (skip in test environment)
  encrypts :github_token unless Rails.env.test?

  # Check if user has a valid GitHub token configured
  def github_token_configured?
    github_token.present?
  end

  # Get a sanitized version of the token for display (show only last 4 chars)
  def github_token_display
    return "Not configured" unless github_token_configured?
    "***#{github_token.last(4)}"
  end
end
