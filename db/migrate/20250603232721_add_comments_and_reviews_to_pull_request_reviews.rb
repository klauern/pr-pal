class AddCommentsAndReviewsToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_request_reviews, :github_comment_count, :integer
    add_column :pull_request_reviews, :github_review_status, :string
  end
end
