class AddLastSyncedAtToPullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_request_reviews, :last_synced_at, :datetime
  end
end
