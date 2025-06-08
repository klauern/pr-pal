# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create demo user if it doesn't exist
demo_user = User.find_or_create_by!(email_address: "test@example.com") do |user|
  user.password = "password"
end

# Create sample repositories
repo1 = demo_user.repositories.find_or_create_by!(owner: "octocat", name: "Hello-World")
repo2 = demo_user.repositories.find_or_create_by!(owner: "rails", name: "rails")

# Create sample pull requests
pr1 = repo1.pull_requests.find_or_create_by!(
  github_pr_id: 123
) do |pr|
  pr.github_pr_url = "https://github.com/octocat/Hello-World/pull/123"
  pr.title = "Add new authentication feature"
  pr.state = "open"
  pr.author = "octocat"
  pr.github_created_at = 2.days.ago
  pr.github_updated_at = 1.hour.ago
end

pr2 = repo2.pull_requests.find_or_create_by!(
  github_pr_id: 456
) do |pr|
  pr.github_pr_url = "https://github.com/rails/rails/pull/456"
  pr.title = "Improve database performance for ActiveRecord queries"
  pr.state = "open"
  pr.author = "rails"
  pr.github_created_at = 3.days.ago
  pr.github_updated_at = 30.minutes.ago
end

# Create sample PR reviews
review1 = demo_user.pull_request_reviews.find_or_create_by!(
  repository: repo1,
  github_pr_id: 123,
  pull_request: pr1
) do |review|
  review.github_pr_url = "https://github.com/octocat/Hello-World/pull/123"
  review.github_pr_title = "Add new authentication feature"
  review.status = "in_progress"
  review.llm_context_summary = "Focus on security implications and best practices for authentication"
  review.last_viewed_at = 1.hour.ago
end

review2 = demo_user.pull_request_reviews.find_or_create_by!(
  repository: repo2,
  github_pr_id: 456,
  pull_request: pr2
) do |review|
  review.github_pr_url = "https://github.com/rails/rails/pull/456"
  review.github_pr_title = "Improve database performance for ActiveRecord queries"
  review.status = "in_progress"
  review.llm_context_summary = "Review for potential N+1 queries and indexing improvements"
  review.last_viewed_at = 30.minutes.ago
end

# Create sample conversation messages
if review1.llm_conversation_messages.empty?
  review1.llm_conversation_messages.create!([
    {
      sender: "user",
      content: "Can you review this authentication PR for security vulnerabilities?",
      order: 1,
      timestamp: 1.hour.ago
    },
    {
      sender: "claude_3_opus",
      content: "I'll analyze this pull request for security vulnerabilities. Based on the authentication changes, I can see several areas that need attention:\n\n1. Password validation appears to be missing complexity requirements\n2. No rate limiting on login attempts\n3. Session management could be improved\n\nWould you like me to go deeper into any of these areas?",
      llm_model_used: "claude-3-opus-20240229",
      token_count: 157,
      order: 2,
      timestamp: 55.minutes.ago
    },
    {
      sender: "user",
      content: "Yes, please elaborate on the session management concerns.",
      order: 3,
      timestamp: 50.minutes.ago
    }
  ])
end

if review2.llm_conversation_messages.empty?
  review2.llm_conversation_messages.create!([
    {
      sender: "user",
      content: "What potential performance issues do you see in this ActiveRecord changes?",
      order: 1,
      timestamp: 25.minutes.ago
    }
  ])
end

puts "Seed data created successfully!"
puts "Demo user: test@example.com / password"
puts "- #{demo_user.repositories.count} repositories"
puts "- #{demo_user.pull_request_reviews.in_progress.count} active PR reviews"
puts "- #{LlmConversationMessage.joins(:pull_request_review).where(pull_request_review: { user: demo_user }).count} conversation messages"
