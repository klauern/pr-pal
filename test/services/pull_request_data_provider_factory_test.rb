# frozen_string_literal: true

require "test_helper"

class PullRequestDataProviderFactoryTest < ActiveSupport::TestCase
  class FakeUser
    def initialize(has_token)
      @has_token = has_token
    end

    def github_token_configured?
      @has_token
    end
  end

  def setup
    @orig_provider_env = ENV["PULL_REQUEST_DATA_PROVIDER"]
    @orig_force_env = ENV["FORCE_DUMMY_DATA"]
  end

  def teardown
    ENV["PULL_REQUEST_DATA_PROVIDER"] = @orig_provider_env
    ENV["FORCE_DUMMY_DATA"] = @orig_force_env
  end

  test "returns dummy provider for nil user" do
    assert_equal DummyPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(nil)
  end

  test "returns dummy provider when user lacks github_token_configured? method" do
    user = Object.new
    assert_equal DummyPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(user)
  end

  test "returns dummy provider when github_token_configured? is false" do
    user = FakeUser.new(false)
    assert_equal DummyPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(user)
  end

  test "returns dummy provider when explicit dummy mode via PULL_REQUEST_DATA_PROVIDER" do
    user = FakeUser.new(true)
    ENV["PULL_REQUEST_DATA_PROVIDER"] = "dummy"
    assert_equal DummyPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(user)
  end

  test "returns dummy provider when explicit dummy mode via FORCE_DUMMY_DATA" do
    user = FakeUser.new(true)
    ENV["FORCE_DUMMY_DATA"] = "true"
    assert_equal DummyPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(user)
  end

  test "returns GitHub provider when token configured and no dummy mode" do
    user = FakeUser.new(true)
    ENV.delete("PULL_REQUEST_DATA_PROVIDER")
    ENV.delete("FORCE_DUMMY_DATA")
    assert_equal GithubPullRequestDataProvider, PullRequestDataProviderFactory.provider_for(user)
  end
end