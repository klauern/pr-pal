ENV["RAILS_ENV"] ||= "test"
require "simplecov"

# Always generate .resultset.json for GitHub Actions artifact upload
# SimpleCov automatically generates .resultset.json, so we only need HTML formatter
SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter

SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  enable_coverage_for_eval
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
