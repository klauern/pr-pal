# frozen_string_literal: true

require "test_helper"

class PullRequestDataProviderTest < ActiveSupport::TestCase
  test "base class fetch_or_create_pr_review raises NotImplementedError" do
    assert_raises(NotImplementedError) do
      PullRequestDataProvider.fetch_or_create_pr_review(owner: "o", name: "n", pr_number: 1, user: nil)
    end
  end

  test "base class fetch_repository_pull_requests raises NotImplementedError" do
    assert_raises(NotImplementedError) do
      PullRequestDataProvider.fetch_repository_pull_requests("repo", nil)
    end
  end
end
