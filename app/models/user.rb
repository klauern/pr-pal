class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :repositories, dependent: :destroy
  has_many :pull_request_reviews, dependent: :destroy
  has_many :llm_api_keys, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

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

  # LLM preferences
  def preferred_llm_provider
    default_llm_provider.presence || llm_api_keys.first&.llm_provider
  end

  def preferred_llm_model
    default_llm_model.presence
  end

  def set_preferred_llm(provider:, model: nil)
    self.default_llm_provider = provider
    self.default_llm_model = model
    save!
  end
end
