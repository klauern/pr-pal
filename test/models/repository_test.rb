require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @repository = repositories(:one)
    @valid_attributes = {
      owner: "testowner",
      name: "testrepo",
      user: @user
    }
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    repository = Repository.new(@valid_attributes)
    assert repository.valid?
  end

  test "should require owner" do
    repository = Repository.new(@valid_attributes.except(:owner))
    assert_not repository.valid?
    assert_includes repository.errors[:owner], "can't be blank"
  end

  test "should require name" do
    repository = Repository.new(@valid_attributes.except(:name))
    assert_not repository.valid?
    assert_includes repository.errors[:name], "can't be blank"
  end

  test "should require user" do
    repository = Repository.new(@valid_attributes.except(:user))
    assert_not repository.valid?
    assert_includes repository.errors[:user], "must exist"
  end

  test "should enforce uniqueness of owner/name combination per user" do
    # Create first repository
    Repository.create!(@valid_attributes)
    
    # Try to create second repository with same owner/name for same user
    duplicate_repository = Repository.new(@valid_attributes)
    assert_not duplicate_repository.valid?
  end

  test "should allow same owner/name for different users" do
    # Create first repository for user one
    Repository.create!(@valid_attributes)
    
    # Create same owner/name for different user - should be allowed
    other_user = users(:two)
    other_repository = Repository.new(@valid_attributes.merge(user: other_user))
    assert other_repository.valid?
  end

  # Note: Repository model currently doesn't have format validations
  # These would be good to add in the future for security and GitHub API compatibility
  
  test "should accept various owner formats" do
    valid_owners = [
      "user",
      "user123", 
      "user-name",
      "organization",
      "my-org-123",
      "user_name"  # underscores are allowed for now
    ]
    
    valid_owners.each do |owner|
      repository = Repository.new(@valid_attributes.merge(owner: owner, name: "unique-#{owner}"))
      assert repository.valid?, "#{owner} should be valid"
    end
  end

  test "should accept various name formats" do
    valid_names = [
      "repo",
      "my-repo",
      "repo123",
      "awesome-project",
      "web-app-2024"
    ]
    
    valid_names.each do |name|
      repository = Repository.new(@valid_attributes.merge(name: name, owner: "unique-#{name}"))
      assert repository.valid?, "#{name} should be valid"
    end
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @repository, :user
    assert_equal @user, @repository.user
  end

  test "should have many pull_requests" do
    assert_respond_to @repository, :pull_requests
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @repository.pull_requests
  end

  test "should have many pull_request_reviews" do
    assert_respond_to @repository, :pull_request_reviews
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @repository.pull_request_reviews
  end

  test "should destroy dependent pull_requests when repository is destroyed" do
    # Create a pull request
    pull_request = @repository.pull_requests.create!(
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      title: "Test PR",
      state: "open",
      author: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    # Verify PR exists
    assert PullRequest.exists?(pull_request.id)

    # Destroy repository
    @repository.destroy!

    # Verify dependent PR is destroyed
    assert_not PullRequest.exists?(pull_request.id)
  end

  test "should destroy dependent pull_request_reviews when repository is destroyed" do
    # Create a pull request and review
    pull_request = @repository.pull_requests.create!(
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      title: "Test PR",
      state: "open",
      author: "testuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )

    pr_review = @repository.pull_request_reviews.create!(
      user: @user,
      pull_request: pull_request,
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      github_pr_title: "Test PR"
    )

    # Verify review exists
    assert PullRequestReview.exists?(pr_review.id)

    # Destroy repository
    @repository.destroy!

    # Verify dependent review is destroyed
    assert_not PullRequestReview.exists?(pr_review.id)
  end

  # Method Tests
  test "should return full_name as owner/name" do
    repository = Repository.new(owner: "testowner", name: "testrepo")
    assert_equal "testowner/testrepo", repository.full_name
  end

  test "should return github_url" do
    repository = Repository.new(owner: "testowner", name: "testrepo")
    assert_equal "https://github.com/testowner/testrepo", repository.github_url
  end

  test "should handle special characters in github_url" do
    repository = Repository.new(owner: "test-owner", name: "test-repo")
    assert_equal "https://github.com/test-owner/test-repo", repository.github_url
  end

  # Scoping and Queries Tests
  test "should find repositories by user" do
    other_user = users(:two)
    other_repo = Repository.create!(owner: "otherowner", name: "otherrepo", user: other_user)

    user_repos = Repository.where(user: @user)
    assert_includes user_repos, @repository
    assert_not_includes user_repos, other_repo
  end

  test "should order repositories by creation date" do
    newer_repo = Repository.create!(
      owner: "newer",
      name: "newer-repo",
      user: @user,
      created_at: 1.day.from_now
    )

    older_repo = Repository.create!(
      owner: "older", 
      name: "older-repo",
      user: @user,
      created_at: 1.day.ago
    )

    ordered_repos = Repository.where(user: @user).order(:created_at)
    assert_equal older_repo.id, ordered_repos.first.id
    assert_equal newer_repo.id, ordered_repos.last.id
  end

  # Edge Cases
  test "should handle very long owner and name" do
    long_owner = "a" * 39  # GitHub allows up to 39 chars
    long_name = "b" * 100  # GitHub allows up to 100 chars
    
    repository = Repository.new(@valid_attributes.merge(owner: long_owner, name: long_name))
    # Should either be valid or fail gracefully
    assert_nothing_raised { repository.valid? }
    # Since no length validation is implemented, it should be valid
    assert repository.valid?
  end

  test "should handle unicode characters in owner and name" do
    unicode_owner = "tëst-owner"
    unicode_name = "tëst-repo"
    
    repository = Repository.new(@valid_attributes.merge(owner: unicode_owner, name: unicode_name))
    # Should either be valid or fail gracefully
    assert_nothing_raised { repository.valid? }
    # Since no format validation is implemented, it should be valid
    assert repository.valid?
  end

  test "should handle case sensitivity in names" do
    # Create repository with lowercase
    Repository.create!(@valid_attributes.merge(owner: "testowner", name: "testrepo"))
    
    # Try to create with different case
    different_case = Repository.new(@valid_attributes.merge(owner: "TestOwner", name: "TestRepo"))
    # GitHub repos are case sensitive, so this should be allowed
    assert different_case.valid?
  end

  # Business Logic Tests
  test "should have timestamps for created_at and updated_at" do
    assert_respond_to @repository, :created_at
    assert_respond_to @repository, :updated_at
    assert_not_nil @repository.created_at
    assert_not_nil @repository.updated_at
  end

  # Performance Tests
  test "should create repository efficiently" do
    start_time = Time.current
    
    Repository.create!(@valid_attributes.merge(owner: "performance", name: "test"))
    
    end_time = Time.current
    assert (end_time - start_time) < 1.second, "Repository creation should be fast"
  end

  test "should find repository by owner/name efficiently" do
    repo = Repository.create!(@valid_attributes.merge(owner: "findme", name: "quickly"))
    
    start_time = Time.current
    found_repo = Repository.find_by(owner: "findme", name: "quickly")
    end_time = Time.current
    
    assert_equal repo.id, found_repo.id
    assert (end_time - start_time) < 0.1.seconds, "Repository lookup should be very fast"
  end

  # Note: No database-level unique constraint exists on owner/name/user_id
  # Uniqueness is only enforced at the Rails model validation level

  test "should handle concurrent repository creation" do
    # Simulate concurrent repository creation attempts with unique names
    threads = []
    results = []
    
    5.times do |i|
      threads << Thread.new do
        begin
          repo = Repository.create!(@valid_attributes.merge(
            owner: "concurrent#{i}", 
            name: "test#{i}"  # Make names unique too
          ))
          results << repo.persisted?
        rescue => e
          results << e.class
        end
      end
    end
    
    threads.each(&:join)
    
    # All repository creations should succeed
    assert results.all? { |result| result == true }
  end

  # Repository Statistics Tests
  test "should count pull_requests correctly" do
    # Clear any existing PRs from fixtures
    @repository.pull_requests.destroy_all
    
    # Start with no PRs
    assert_equal 0, @repository.pull_requests.count
    
    # Add some PRs
    3.times do |i|
      @repository.pull_requests.create!(
        github_pr_id: i + 100, # Use different IDs to avoid conflicts
        github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/#{i + 100}",
        title: "Test PR #{i + 1}",
        state: "open",
        author: "testuser",
        github_created_at: (i + 1).days.ago,
        github_updated_at: i.hours.ago
      )
    end
    
    assert_equal 3, @repository.pull_requests.count
  end

  test "should count pull_request_reviews correctly" do
    # Clear any existing data from fixtures
    @repository.pull_request_reviews.destroy_all
    @repository.pull_requests.destroy_all
    
    # Start with no reviews
    assert_equal 0, @repository.pull_request_reviews.count
    
    # Add some reviews with unique github_pr_ids
    2.times do |i|
      # Create a unique pull request for each review
      pr = @repository.pull_requests.create!(
        github_pr_id: 300 + i,  # Use 300 range to avoid conflicts
        github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/#{300 + i}",
        title: "Test PR #{i}",
        state: "open",
        author: "testuser",
        github_created_at: 1.day.ago,
        github_updated_at: 1.hour.ago
      )
      
      @repository.pull_request_reviews.create!(
        user: @user,
        pull_request: pr,
        github_pr_id: 300 + i,
        github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/#{300 + i}",
        github_pr_title: "Test PR #{i}"
      )
    end
    
    assert_equal 2, @repository.pull_request_reviews.count
  end

  # Integration Tests
  test "should work with repository sync workflow" do
    # Simulate a sync workflow - create PR during sync
    pr = @repository.pull_requests.create!(
      github_pr_id: 1,
      github_pr_url: "https://github.com/#{@repository.owner}/#{@repository.name}/pull/1",
      title: "Synced PR",
      state: "open",
      author: "syncuser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    
    # Verify workflow completed
    assert @repository.pull_requests.any?
    assert_equal "Synced PR", pr.title
  end
end
