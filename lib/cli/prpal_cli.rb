require "thor"

module Cli
  class Reviews < Thor
    desc "list", "List all pull request reviews"
    def list
      PullRequestReview.find_each do |review|
        puts "#{review.id}: #{review.github_pr_title} [#{review.status}]"
      end
    end

    desc "show ID", "Show details for a pull request review"
    def show(id)
      review = PullRequestReview.find(id)
      puts "ID: #{review.id}"
      puts "Title: #{review.github_pr_title}"
      puts "URL: #{review.github_pr_url}"
      puts "Status: #{review.status}"
    end
  end
end

module Cli
  class PrpalCli < Thor
    desc "reviews SUBCOMMAND ...ARGS", "Manage pull request reviews"
    subcommand "reviews", Reviews
  end
end
