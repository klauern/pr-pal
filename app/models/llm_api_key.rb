class LlmApiKey < ApplicationRecord
  encrypts :api_key

  validates :llm_provider, presence: true, uniqueness: true
  validates :api_key, presence: true
end
