require "test_helper"
require "cli/prpal_cli"

class PrpalCliTest < ActiveSupport::TestCase
  test "list command outputs reviews" do
    output, = capture_io do
      Cli::PrpalCli.start([ "reviews", "list" ])
    end

    assert_includes output, pull_request_reviews(:review_pr_one).github_pr_title
    assert_includes output, pull_request_reviews(:review_pr_two).github_pr_title
  end

  test "show command outputs details" do
    review = pull_request_reviews(:review_pr_one)
    output, = capture_io do
      Cli::PrpalCli.start([ "reviews", "show", review.id.to_s ])
    end

    assert_includes output, review.github_pr_title
    assert_includes output, review.github_pr_url
  end
end
