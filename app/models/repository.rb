class Repository < ApplicationRecord
  belongs_to :user
  has_many :pull_requests, dependent: :destroy
  has_many :pull_request_reviews, dependent: :destroy

  validates :owner, presence: true
  validates :name, presence: true
  validates :name, uniqueness: { scope: [ :owner, :user_id ], message: "has already been added for this owner" }

  def full_name
    "#{owner}/#{name}"
  end

  def github_url
    "https://github.com/#{owner}/#{name}"
  end
end
