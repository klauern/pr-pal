class PullRequestReview < ApplicationRecord
  belongs_to :user
  belongs_to :repository
  has_many :llm_conversation_messages, dependent: :destroy

  validates :github_pr_id, presence: true
  validates :github_pr_url, presence: true
  validates :github_pr_title, presence: true
  validates :status, presence: true, inclusion: { in: %w[in_progress completed archived] }
  validates :github_pr_id, uniqueness: { scope: :repository_id }

  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }

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
end
