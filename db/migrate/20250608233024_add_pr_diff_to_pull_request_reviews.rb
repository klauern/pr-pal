class AddPrDiffToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_request_reviews, :pr_diff, :text
  end
end
