class AddCiStatusToPullRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :pull_requests, :ci_status, :string
    add_column :pull_requests, :ci_status_raw, :text
    add_column :pull_requests, :ci_status_updated_at, :datetime
  end
end
