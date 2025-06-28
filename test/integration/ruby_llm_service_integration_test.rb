require "test_helper"
require "ruby_llm"

class RubyLlmServiceIntegrationTest < ActiveSupport::TestCase
  setup do
    skip "OPENAI_API_KEY not set" unless ENV["OPENAI_API_KEY"].present?
    @review = PullRequestReview.create!(
      user: User.first || User.create!(email_address: "test@example.com", password: "password"),
      repository: Repository.first || Repository.create!(user: User.first, owner: "openai", name: "openai-repo"),
      pull_request: PullRequest.first || PullRequest.create!(repository: Repository.first, github_pr_id: 1, github_pr_url: "https://github.com/openai/openai-repo/pull/1", title: "Test PR", state: "open", author: "test", github_created_at: Time.now, github_updated_at: Time.now),
      github_pr_id: 1,
      github_pr_url: "https://github.com/openai/openai-repo/pull/1",
      github_pr_title: "Test PR",
      status: "in_progress"
    )
    @review.llm_conversation_messages.create!(sender: "user", content: "Say hello in one sentence.", order: 1)
  end

  test "ruby_llm_service returns a valid response from OpenAI" do
    service = RubyLlmService.new(@review)
    response = service.send_user_message("Say hello in one sentence.")
    assert response.is_a?(String), "Response should be a string"
    assert response.length > 0, "Response should not be empty"
    refute_match(/error|invalid|not allowed|forbidden/i, response, "Response should not contain error indications")
  end
end
