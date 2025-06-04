class AddCiStatusToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_request_reviews, :ci_status, :string
    add_column :pull_request_reviews, :ci_url, :string
  end
end
