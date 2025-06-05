class CreatePullRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_requests do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :github_pr_id, null: false
      t.string :github_pr_url, null: false
      t.string :title, null: false
      t.string :state, null: false # open, closed, merged
      t.string :author
      t.text :body
      t.datetime :github_created_at
      t.datetime :github_updated_at
      t.integer :additions
      t.integer :deletions
      t.integer :changed_files
      t.boolean :draft, default: false
      t.string :base_branch
      t.string :head_branch
      t.text :labels # JSON array of label names
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :pull_requests, [ :repository_id, :github_pr_id ], unique: true
    add_index :pull_requests, :state
    add_index :pull_requests, :github_created_at
  end
end
