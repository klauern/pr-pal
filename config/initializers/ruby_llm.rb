# frozen_string_literal: true

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.openai_base_url = ENV["OPENAI_BASE_URL"] if ENV["OPENAI_BASE_URL"].present?
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  # Add other provider configs as needed
end
