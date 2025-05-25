class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :repositories, dependent: :destroy
  has_many :pull_request_reviews, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
