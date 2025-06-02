class PullRequest < ApplicationRecord
  belongs_to :repository
  has_many :pull_request_reviews, dependent: :destroy

  validates :repository_id, presence: true
  validates :github_pr_id, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true
  validates :state, presence: true
  validates :author, presence: true
  validates :github_url, presence: true

  scope :open, -> { where(state: "open") }
  scope :closed, -> { where(state: "closed") }
  scope :merged, -> { where(state: "merged") }
  scope :by_interest, -> { order(review_interest: :desc) }

  def closed?
    state == "closed"
  end

  def merged?
    state == "merged"
  end

  def open?
    state == "open"
  end

  def number
    github_pr_id
  end
end
