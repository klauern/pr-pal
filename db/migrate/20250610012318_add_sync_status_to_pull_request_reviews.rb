class AddSyncStatusToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_request_reviews, :sync_status, :string, default: 'pending', null: false
    add_index :pull_request_reviews, :sync_status
  end
end
