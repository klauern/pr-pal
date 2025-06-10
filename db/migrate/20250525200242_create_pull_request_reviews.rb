class CreatePullRequestReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_request_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      t.integer :github_pr_id, null: false
      t.string :github_pr_url, null: false
      t.string :github_pr_title, null: false
      t.string :status, null: false, default: 'in_progress'
      t.text :llm_context_summary
      t.text :pr_diff
      t.string :active_llm_session_id
      t.datetime :last_viewed_at

      t.timestamps
    end

    add_index :pull_request_reviews, [ :user_id, :status ]
    add_index :pull_request_reviews, [ :repository_id, :github_pr_id ], unique: true
  end
end
