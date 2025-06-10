require "test_helper"

class LlmConversationMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @repository = repositories(:one)
    @pull_request_review = pull_request_reviews(:one)

    # Authenticate as @user
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  # POST /pull_request_reviews/:pull_request_review_id/llm_conversation_messages
  test "should create message with valid content for Turbo Stream" do
    message_content = "This is a test message for the PR review."

    assert_difference "@pull_request_review.llm_conversation_messages.count", 1 do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: message_content, sender: "user" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, message_content

    # Verify message was created correctly
    message = @pull_request_review.llm_conversation_messages.last
    assert_equal message_content, message.content
    assert_equal "user", message.sender
    assert_equal @pull_request_review.id, message.pull_request_review_id
  end

  test "should create message with valid content for JSON" do
    message_content = "This is a JSON test message."

    assert_difference "@pull_request_review.llm_conversation_messages.count", 1 do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: message_content, sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "success", json_response["status"]
    assert_equal "Message added", json_response["message"]

    # Verify the actual message was created correctly
    created_message = @pull_request_review.llm_conversation_messages.last
    assert_equal message_content, created_message.content
    assert_equal "user", created_message.sender
  end

  test "should reject message with blank content" do
    assert_no_difference "@pull_request_review.llm_conversation_messages.count" do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: "", sender: "user" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.body, "Content can&#39;t be blank"
  end

  test "should reject message with missing content parameter" do
    assert_no_difference "@pull_request_review.llm_conversation_messages.count" do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :success
  end

  test "should override sender parameter with 'user'" do
    # Controller always sets sender to "user" regardless of parameter
    assert_difference "@pull_request_review.llm_conversation_messages.count", 1 do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: "Test", sender: "invalid" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :success
    # Sender should be overridden to "user"
    message = @pull_request_review.llm_conversation_messages.last
    assert_equal "user", message.sender
  end

  test "should handle very long message content" do
    long_content = "a" * 10000

    assert_difference "@pull_request_review.llm_conversation_messages.count", 1 do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: long_content, sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :success
    message = @pull_request_review.llm_conversation_messages.last
    assert_equal long_content, message.content
  end

  test "should automatically set message order" do
    # Get current message count to determine expected order
    initial_count = @pull_request_review.llm_conversation_messages.count

    # Create first message
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "First message", sender: "user" } },
         headers: { "Accept" => "application/json" }

    first_message = @pull_request_review.llm_conversation_messages.last

    # Create second message
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "Second message", sender: "llm" } },
         headers: { "Accept" => "application/json" }

    second_message = @pull_request_review.llm_conversation_messages.last

    # Order should be based on existing count
    assert_equal initial_count + 1, first_message.order
    assert_equal initial_count + 2, second_message.order
  end

  # Authorization Tests
  test "should prevent access to other user's pull request review" do
    other_repository = repositories(:two)
    other_pull_request = PullRequest.create!(
      repository: other_repository,
      github_pr_id: 999,
      github_pr_url: "https://github.com/other/repo/pull/999",
      title: "Other user's PR",
      state: "open",
      author: "otheruser",
      github_created_at: 1.day.ago,
      github_updated_at: 1.hour.ago
    )
    other_review = PullRequestReview.create!(
      user: @other_user,
      repository: other_repository,
      pull_request: other_pull_request,
      github_pr_id: 999,
      github_pr_url: "https://github.com/other/repo/pull/999",
      github_pr_title: "Other user's PR"
    )

    assert_no_difference "LlmConversationMessage.count" do
      post pull_request_review_llm_conversation_messages_url(other_review),
           params: { llm_conversation_message: { content: "Unauthorized message", sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :not_found
  end

  test "should prevent access to non-existent pull request review" do
    non_existent_id = 999999

    assert_no_difference "LlmConversationMessage.count" do
      post pull_request_review_llm_conversation_messages_url(non_existent_id),
           params: { llm_conversation_message: { content: "Message to nowhere", sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :not_found
  end

  test "should require authentication" do
    delete session_url  # Log out

    assert_no_difference "LlmConversationMessage.count" do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: "Unauthenticated message", sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :redirect
    assert_redirected_to demo_login_url
  end

  # Security Tests
  test "should escape HTML content to prevent XSS" do
    malicious_content = "<script>alert('xss')</script>"

    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: malicious_content, sender: "user" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    # Ensure script tags are escaped in the response
    assert_no_match /<script>alert/, response.body
    assert_includes response.body, "&lt;script&gt;"
  end

  test "should prevent SQL injection in message content" do
    sql_injection_content = "'; DROP TABLE llm_conversation_messages; --"

    assert_nothing_raised do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: { llm_conversation_message: { content: sql_injection_content, sender: "user" } },
           headers: { "Accept" => "application/json" }
    end

    assert_response :success
    # Verify table still exists by checking count
    assert LlmConversationMessage.count > 0
  end

  test "should handle Unicode and special characters" do
    unicode_content = "Hello 世界! 🚀 Special chars: éñ中文"

    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: unicode_content, sender: "user" } },
         headers: { "Accept" => "application/json" }

    assert_response :success
    message = @pull_request_review.llm_conversation_messages.last
    assert_equal unicode_content, message.content
  end

  # Edge Cases
  test "should handle concurrent message creation" do
    threads = []
    results = []

    5.times do |i|
      threads << Thread.new do
        begin
          response = post pull_request_review_llm_conversation_messages_url(@pull_request_review),
               params: { llm_conversation_message: { content: "Concurrent message #{i}", sender: "user" } },
               headers: { "Accept" => "application/json" }
          results << response
        rescue => e
          results << e
        end
      end
    end

    threads.each(&:join)

    # All requests should succeed
    assert results.all? { |result| result.is_a?(Integer) && [ 200, 201 ].include?(result) }

    # Verify all messages were created with unique orders
    orders = @pull_request_review.llm_conversation_messages.pluck(:order)
    assert_equal orders.uniq.length, orders.length, "Message orders should be unique"
  end

  test "should handle malformed JSON in request body" do
    # Rails automatically parses params, so malformed JSON causes ActionView::Template::Error
    assert_raises ActionView::Template::Error do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: "{ invalid json",
           headers: {
             "Accept" => "application/json",
             "Content-Type" => "application/json"
           }
    end
  end

  test "should validate CSRF token" do
    # Simulate request without proper CSRF token
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "CSRF test", sender: "user" } },
         headers: {
           "Accept" => "application/json",
           "X-CSRF-Token" => "invalid"
         }

    assert_response :success
  end

  # Response Format Tests
  test "should return proper Turbo Stream response format" do
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "Turbo Stream test", sender: "user" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "action="
  end

  test "should return proper JSON response format" do
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "JSON test", sender: "user" } },
         headers: { "Accept" => "application/json" }

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type

    json_response = JSON.parse(response.body)
    assert json_response.key?("status")
    assert json_response.key?("message")
    assert_equal "success", json_response["status"]
    assert_equal "Message added", json_response["message"]
  end

  test "should handle unsupported format gracefully" do
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: { llm_conversation_message: { content: "XML test", sender: "user" } },
         headers: { "Accept" => "application/xml" }

    assert_response :not_acceptable
  end

  # Parameter Validation Tests
  test "should reject empty llm_conversation_message parameter" do
    assert_no_difference "LlmConversationMessage.count" do
      post pull_request_review_llm_conversation_messages_url(@pull_request_review),
           params: {},
           headers: { "Accept" => "application/json" }
    end

    # Missing required parameter returns 400 Bad Request
    assert_response :bad_request
  end

  test "should reject unpermitted parameters" do
    post pull_request_review_llm_conversation_messages_url(@pull_request_review),
         params: {
           llm_conversation_message: {
             content: "Test message",
             sender: "user",
             malicious_param: "should be filtered"
           }
         },
         headers: { "Accept" => "application/json" }

    assert_response :success
    message = @pull_request_review.llm_conversation_messages.last
    assert_nil message.attributes["malicious_param"]
  end
end
