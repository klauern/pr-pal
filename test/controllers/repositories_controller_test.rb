require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @repository = repositories(:one)
  end

  test "should get index when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    get repositories_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get repositories_url
    assert_redirected_to demo_login_url
  end

  test "should create repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_difference('Repository.count') do
      post repositories_url, params: { repository: { owner: "testowner", name: "testrepo" } }
    end
    assert_redirected_to repositories_url
  end

  test "should destroy repository when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_difference('Repository.count', -1) do
      delete repository_url(@repository)
    end
    assert_redirected_to repositories_url
  end

  test "should not create repository with missing owner" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference('Repository.count') do
      post repositories_url, params: { repository: { name: "testrepo" } }
    end
    assert_response :unprocessable_entity
    # The validation error should be present
    assert assigns(:repository).errors[:owner].any?
  end

  test "should not create repository with missing name" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference('Repository.count') do
      post repositories_url, params: { repository: { owner: "testowner" } }
    end
    assert_response :unprocessable_entity
    # The validation error should be present
    assert assigns(:repository).errors[:name].any?
  end

  test "should not create duplicate repository for same user" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    assert_no_difference('Repository.count') do
      post repositories_url, params: { repository: { owner: @repository.owner, name: @repository.name } }
    end
    assert_response :unprocessable_entity
    # The uniqueness validation error should be present
    assert assigns(:repository).errors.any?
  end

  test "should not allow user to destroy another user's repository" do
    other_user = users(:two)
    other_repository = repositories(:two)

    post session_url, params: { email_address: @user.email_address, password: "password" }

    # Try to delete another user's repository - should result in RecordNotFound or no change
    begin
      delete repository_url(other_repository)
      # If we get here, the delete didn't raise an exception
      # Check that the repository still exists
      assert Repository.exists?(other_repository.id), "Repository should still exist"
    rescue ActiveRecord::RecordNotFound
      # This is the expected behavior
      assert true
    end
  end
end
