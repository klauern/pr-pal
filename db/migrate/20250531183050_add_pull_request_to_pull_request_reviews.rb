class AddPullRequestToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_reference :pull_request_reviews, :pull_request, null: false, foreign_key: true
  end
end
