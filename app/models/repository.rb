class Repository < ApplicationRecord
  belongs_to :user

  validates :owner, presence: true
  validates :name, presence: true
  validates :owner, :name, uniqueness: { scope: :user_id }
end
