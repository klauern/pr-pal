ENV["RAILS_ENV"] ||= "test"
require "simplecov"

# Configure Codecov if running in CI
if ENV["CI"]
  require "codecov"
  codecov_formatter = SimpleCov::Formatter.const_get("Codecov")
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    codecov_formatter
  ])
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end

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
