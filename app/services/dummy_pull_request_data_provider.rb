# Dummy data provider - wraps existing auto-creation logic
# Creates repositories and PR reviews with realistic dummy data
class DummyPullRequestDataProvider < PullRequestDataProvider
  def self.fetch_or_create_pr_review(owner:, name:, pr_number:, user:)
    # Find or create repository (same as existing logic)
    repository = user.repositories.find_or_create_by(
      owner: owner,
      name: name
    )

    # Find or create pull request review with proper repository association
    pull_request_review = user.pull_request_reviews.find_or_initialize_by(
      github_pr_id: pr_number,
      repository: repository
    )

    # If this is a new review, set default values with dummy data
    if pull_request_review.new_record?
      # Create the PullRequest record first
      pr_title = generate_dummy_pr_title(repository, pr_number)
      pr_url = "#{repository.github_url}/pull/#{pr_number}"
      
      pull_request = repository.pull_requests.find_or_create_by!(
        github_pr_id: pr_number
      ) do |pr|
        pr.title = pr_title
        pr.body = "This is a dummy pull request for testing and development purposes."
        pr.state = "open"
        pr.author = "dummy-developer"
        pr.github_pr_url = pr_url
        pr.github_created_at = 3.days.ago
        pr.github_updated_at = 1.hour.ago
      end
      
      pull_request_review.assign_attributes(
        github_pr_title: pr_title,
        github_pr_url: pr_url,
        status: "in_progress",
        pr_diff: generate_dummy_pr_diff(repository, pr_number),
        pull_request: pull_request
      )

      unless pull_request_review.save
        raise "Failed to create review: #{pull_request_review.errors.full_messages.join(', ')}"
      end
    end

    [ repository, pull_request_review ]
  end

  private

  def self.generate_dummy_pr_title(repository, pr_number)
    # Generate more realistic dummy PR titles
    dummy_titles = [
      "Fix authentication bug in user sessions",
      "Add responsive design for mobile devices",
      "Implement caching for improved performance",
      "Update dependencies and security patches",
      "Refactor user profile component",
      "Add integration tests for API endpoints",
      "Improve error handling in payment flow",
      "Update documentation and README",
      "Fix memory leak in background jobs",
      "Add feature flags for A/B testing"
    ]

    base_title = dummy_titles.sample
    "#{base_title} (##{pr_number})"
  end

  def self.generate_dummy_pr_diff(repository, pr_number)
    # Generate realistic PR diff content based on the repository type
    language = detect_language_from_repo(repository.name)
    
    case language
    when :ruby
      generate_ruby_diff(repository, pr_number)
    when :javascript
      generate_javascript_diff(repository, pr_number) 
    when :python
      generate_python_diff(repository, pr_number)
    else
      generate_generic_diff(repository, pr_number)
    end
  end

  def self.detect_language_from_repo(repo_name)
    return :ruby if repo_name.include?('rails') || repo_name.include?('ruby')
    return :javascript if repo_name.include?('js') || repo_name.include?('node') || repo_name.include?('react')
    return :python if repo_name.include?('py') || repo_name.include?('django') || repo_name.include?('flask')
    :generic
  end

  def self.generate_ruby_diff(repository, pr_number)
    <<~DIFF
      diff --git a/app/controllers/users_controller.rb b/app/controllers/users_controller.rb
      index 1234567..abcdefg 100644
      --- a/app/controllers/users_controller.rb
      +++ b/app/controllers/users_controller.rb
      @@ -15,8 +15,12 @@ class UsersController < ApplicationController
         end
       
         def update
      -    if @user.update(user_params)
      +    if @user.update(user_params) && verify_user_permissions
             redirect_to @user, notice: 'User was successfully updated.'
      +    elsif !verify_user_permissions
      +      redirect_to @user, alert: 'Insufficient permissions to update user.'
           else
             render :edit
           end
      @@ -28,6 +32,10 @@ class UsersController < ApplicationController
         def user_params
           params.require(:user).permit(:name, :email, :role)
         end
      +
      +  def verify_user_permissions
      +    current_user.admin? || current_user == @user
      +  end
       end
      
      diff --git a/test/controllers/users_controller_test.rb b/test/controllers/users_controller_test.rb
      index 9876543..fedcba9 100644
      --- a/test/controllers/users_controller_test.rb
      +++ b/test/controllers/users_controller_test.rb
      @@ -45,4 +45,14 @@ class UsersControllerTest < ActionDispatch::IntegrationTest
           assert_response :success
         end
       end
      +
      +  test "should not allow regular user to update other users" do
      +    other_user = users(:jane)
      +    sign_in_as users(:regular_user)
      +    
      +    patch user_url(other_user), params: { user: { name: "Hacked Name" } }
      +    
      +    assert_redirected_to other_user
      +    assert_match "Insufficient permissions", flash[:alert]
      +  end
       end
    DIFF
  end

  def self.generate_javascript_diff(repository, pr_number)
    <<~DIFF
      diff --git a/src/components/UserProfile.jsx b/src/components/UserProfile.jsx
      index 1234567..abcdefg 100644
      --- a/src/components/UserProfile.jsx
      +++ b/src/components/UserProfile.jsx
      @@ -1,4 +1,5 @@
       import React, { useState, useEffect } from 'react';
      +import { useAuth } from '../hooks/useAuth';
       import { Card, Button, Alert } from './ui';
       
       const UserProfile = ({ userId }) => {
      @@ -6,6 +7,7 @@ const UserProfile = ({ userId }) => {
         const [loading, setLoading] = useState(true);
         const [error, setError] = useState(null);
         const [editing, setEditing] = useState(false);
      +  const { user: currentUser, hasPermission } = useAuth();
       
         useEffect(() => {
           fetchUser();
      @@ -25,6 +27,11 @@ const UserProfile = ({ userId }) => {
         };
       
         const handleEdit = () => {
      +    if (!hasPermission('user:edit', user)) {
      +      setError('You do not have permission to edit this user');
      +      return;
      +    }
      +
           setEditing(true);
         };
       
      @@ -45,7 +52,7 @@ const UserProfile = ({ userId }) => {
               <h2>{user.name}</h2>
               <p>{user.email}</p>
               <p>Role: {user.role}</p>
      -        <Button onClick={handleEdit}>Edit Profile</Button>
      +        {hasPermission('user:edit', user) && <Button onClick={handleEdit}>Edit Profile</Button>}
             </Card>
           )}
         </div>
    DIFF
  end

  def self.generate_python_diff(repository, pr_number)
    <<~DIFF
      diff --git a/app/models/user.py b/app/models/user.py
      index 1234567..abcdefg 100644
      --- a/app/models/user.py
      +++ b/app/models/user.py
      @@ -1,5 +1,6 @@
       from django.db import models
       from django.contrib.auth.models import AbstractUser
      +from django.core.exceptions import PermissionDenied
       
       class User(AbstractUser):
           ROLE_CHOICES = [
      @@ -15,6 +16,15 @@ class User(AbstractUser):
           def __str__(self):
               return f"{self.username} ({self.get_role_display()})"
       
      +    def can_edit_user(self, target_user):
      +        """Check if this user can edit the target user"""
      +        if self.role == 'admin':
      +            return True
      +        if self == target_user:
      +            return True
      +        return False
      +
           def save(self, *args, **kwargs):
               if not self.pk and not self.role:
                   self.role = 'user'
      
      diff --git a/app/views.py b/app/views.py
      index 9876543..fedcba9 100644
      --- a/app/views.py
      +++ b/app/views.py
      @@ -25,6 +25,10 @@ def update_user(request, user_id):
           if request.method == 'POST':
               user = get_object_or_404(User, id=user_id)
               
      +        if not request.user.can_edit_user(user):
      +            messages.error(request, 'You do not have permission to edit this user.')
      +            return redirect('user_detail', user_id=user.id)
      +
               form = UserForm(request.POST, instance=user)
               if form.is_valid():
                   form.save()
    DIFF
  end

  def self.generate_generic_diff(repository, pr_number)
    <<~DIFF
      diff --git a/README.md b/README.md
      index 1234567..abcdefg 100644
      --- a/README.md
      +++ b/README.md
      @@ -1,4 +1,4 @@
      -# #{repository.name}
      +# #{repository.name} - Enhanced Security
       
       A sample application demonstrating best practices.
       
      @@ -15,6 +15,12 @@ To get started:
       3. Run the application
       4. Navigate to localhost:3000
       
      +## Security Features
      +
      +This update includes:
      +- Enhanced user permission checking
      +- Improved access control validation
      +- Better error handling for unauthorized actions
      +
       ## Contributing
       
       Please read our contributing guidelines before submitting PRs.
      
      diff --git a/config/security.yml b/config/security.yml
      new file mode 100644
      index 0000000..1234567
      --- /dev/null
      +++ b/config/security.yml
      @@ -0,0 +1,8 @@
      +security:
      +  permissions:
      +    user_edit: 
      +      - admin
      +      - self
      +  validation:
      +    strict_mode: true
      +    log_violations: true
    DIFF
  end

  # Fetch all pull requests for a repository (dummy data)
  def self.fetch_repository_pull_requests(repository, user)
    # Generate some dummy pull requests
    pr_count = rand(3..8)

    (1..pr_count).map do |i|
      pr_number = i + rand(10..100)
      state = [ "open", "open", "open", "closed", "merged" ].sample # More open PRs

      {
        github_pr_number: pr_number,
        title: generate_dummy_pr_title(repository, pr_number).gsub(" (##{pr_number})", ""),
        body: "This is a dummy pull request for testing purposes. Repository: #{repository.full_name}",
        state: state,
        author: [ "developer1", "codereviewer", "teamlead", "contributor" ].sample,
        github_url: "#{repository.github_url}/pull/#{pr_number}",
        github_created_at: rand(30.days).seconds.ago,
        github_updated_at: rand(7.days).seconds.ago
      }
    end
  end
end
