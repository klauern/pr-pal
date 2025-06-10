class PullRequestReview < ApplicationRecord
  belongs_to :user
  belongs_to :repository
  belongs_to :pull_request
  has_many :llm_conversation_messages, dependent: :destroy

  validates :github_pr_id, presence: true
  validates :github_pr_url, presence: true
  validates :github_pr_title, presence: true
  validates :status, presence: true, inclusion: { in: %w[in_progress completed archived] }
  validates :github_pr_id, uniqueness: { scope: :repository_id }

  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }

  # Hidden field for storing the raw PR diff for LLM context
  # This is not exposed in the UI
  # attr_accessor :pr_diff # (handled by migration)

  def mark_as_completed!
    update!(status: "completed")
  end

  def mark_as_viewed!
    update!(last_viewed_at: Time.current)
  end

  def total_message_count
    llm_conversation_messages.count
  end

  def last_message
    llm_conversation_messages.order(:order).last
  end

  def stale_data?
    return true unless last_synced_at
    last_synced_at < 1.hour.ago
  end

  def needs_auto_sync?
    return false if syncing?
    return true unless last_synced_at
    last_synced_at < 15.minutes.ago
  end

  def syncing?
    sync_status == "syncing"
  end

  def sync_completed?
    sync_status == "completed"
  end

  def sync_failed?
    sync_status == "failed"
  end
end
