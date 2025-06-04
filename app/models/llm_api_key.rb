class LlmApiKey < ApplicationRecord
  belongs_to :user
  encrypts :api_key unless Rails.env.test?

  validates :llm_provider, presence: true, uniqueness: { scope: :user_id }
  validates :api_key, presence: true
end
