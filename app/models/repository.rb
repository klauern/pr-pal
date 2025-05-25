class Repository < ApplicationRecord
  belongs_to :user
  has_many :pull_request_reviews, dependent: :destroy

  validates :owner, presence: true
  validates :name, presence: true
  validates :owner, :name, uniqueness: { scope: :user_id }

  def full_name
    "#{owner}/#{name}"
  end

  def github_url
    "https://github.com/#{owner}/#{name}"
  end
end
