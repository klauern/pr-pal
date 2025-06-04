require "test_helper"

class LlmApiKeyTest < ActiveSupport::TestCase
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
  end

  test "allows same provider for different users" do
    LlmApiKey.create!(user: @user_one, llm_provider: "test_provider", api_key: "k1")
    another = LlmApiKey.new(user: @user_two, llm_provider: "test_provider", api_key: "k2")
    assert another.valid?
  end

  test "disallows duplicate provider for same user" do
    LlmApiKey.create!(user: @user_one, llm_provider: "dup_provider", api_key: "k1")
    dup = LlmApiKey.new(user: @user_one, llm_provider: "dup_provider", api_key: "k2")
    assert_not dup.valid?
  end
end
