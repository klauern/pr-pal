require "test_helper"

class ProcessLlmResponseJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:one)
    @user_message = llm_conversation_messages(:user_message)
  end

  test "should handle missing user message" do
    assert_raises ActiveRecord::RecordNotFound do
      ProcessLlmResponseJob.perform_now(@pull_request_review.id, 999999)
    end
  end

  test "should handle missing pull request review" do
    assert_raises ActiveRecord::RecordNotFound do
      ProcessLlmResponseJob.perform_now(999999, @user_message.id)
    end
  end
end