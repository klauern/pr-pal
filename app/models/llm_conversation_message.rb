class LlmConversationMessage < ApplicationRecord
  belongs_to :pull_request_review

  validates :sender, presence: true
  validates :content, presence: true
  validates :order, presence: true, numericality: { greater_than: 0 }
  validates :order, uniqueness: { scope: :pull_request_review_id }

  scope :ordered, -> { order(:order) }
  scope :by_user, -> { where(sender: "user") }
  scope :by_llm, -> { where.not(sender: "user") }

  before_validation :set_timestamp, on: :create
  before_validation :set_order, on: :create

  def from_user?
    sender == "user"
  end

  def from_llm?
    !from_user?
  end

  private

  def set_timestamp
    self.timestamp ||= Time.current
  end

  def set_order
    return if order.present?

    last_order = pull_request_review.llm_conversation_messages.maximum(:order) || 0
    self.order = last_order + 1
  end
end
