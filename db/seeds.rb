# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create an admin user if one doesn't exist
if User.find_by(email_address: "admin@example.com").nil?
  User.create!(
    email_address: "admin@example.com",
    password: "password", # Consider using environment variables for production passwords
    password_confirmation: "password"
  )
  puts "Admin user created: admin@example.com"
else
  puts "Admin user already exists."
end
