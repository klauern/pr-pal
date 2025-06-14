# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_10_012318) do
  create_table "llm_api_keys", force: :cascade do |t|
    t.string "llm_provider"
    t.text "api_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "full_name"
    t.text "description"
    t.text "aliases"
    t.integer "user_id", null: false
    t.index ["user_id", "llm_provider"], name: "index_llm_api_keys_on_user_id_and_llm_provider", unique: true
    t.index ["user_id"], name: "index_llm_api_keys_on_user_id"
  end

  create_table "llm_conversation_messages", force: :cascade do |t|
    t.integer "pull_request_review_id", null: false
    t.string "sender", null: false
    t.text "content", null: false
    t.string "llm_model_used"
    t.integer "token_count"
    t.text "metadata"
    t.datetime "timestamp", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_review_id", "order"], name: "idx_on_pull_request_review_id_order_193136b580"
    t.index ["pull_request_review_id"], name: "index_llm_conversation_messages_on_pull_request_review_id"
    t.index ["timestamp"], name: "index_llm_conversation_messages_on_timestamp"
  end

  create_table "pull_request_reviews", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "repository_id", null: false
    t.integer "github_pr_id", null: false
    t.string "github_pr_url", null: false
    t.string "github_pr_title", null: false
    t.string "status", default: "in_progress", null: false
    t.text "llm_context_summary"
    t.string "active_llm_session_id"
    t.datetime "last_viewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_synced_at"
    t.integer "pull_request_id", null: false
    t.string "ci_status"
    t.string "ci_url"
    t.integer "github_comment_count"
    t.string "github_review_status"
    t.text "pr_diff"
    t.string "sync_status", default: "pending", null: false
    t.index ["pull_request_id"], name: "index_pull_request_reviews_on_pull_request_id"
    t.index ["repository_id", "github_pr_id"], name: "index_pull_request_reviews_on_repository_id_and_github_pr_id", unique: true
    t.index ["repository_id"], name: "index_pull_request_reviews_on_repository_id"
    t.index ["sync_status"], name: "index_pull_request_reviews_on_sync_status"
    t.index ["user_id", "status"], name: "index_pull_request_reviews_on_user_id_and_status"
    t.index ["user_id"], name: "index_pull_request_reviews_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "github_pr_id", null: false
    t.string "github_pr_url", null: false
    t.string "title", null: false
    t.string "state", null: false
    t.string "author"
    t.text "body"
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.integer "additions"
    t.integer "deletions"
    t.integer "changed_files"
    t.boolean "draft", default: false
    t.string "base_branch"
    t.string "head_branch"
    t.text "labels"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ci_status"
    t.text "ci_status_raw"
    t.datetime "ci_status_updated_at"
    t.index ["github_created_at"], name: "index_pull_requests_on_github_created_at"
    t.index ["repository_id", "github_pr_id"], name: "index_pull_requests_on_repository_id_and_github_pr_id", unique: true
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
    t.index ["state"], name: "index_pull_requests_on_state"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "owner"
    t.string "name"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_repositories_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "github_token"
    t.string "default_llm_provider"
    t.string "default_llm_model"
    t.text "llm_params"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "llm_api_keys", "users"
  add_foreign_key "llm_conversation_messages", "pull_request_reviews"
  add_foreign_key "pull_request_reviews", "pull_requests"
  add_foreign_key "pull_request_reviews", "repositories"
  add_foreign_key "pull_request_reviews", "users"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "repositories", "users"
  add_foreign_key "sessions", "users"
end
