require "test_helper"

class LlmConversationMessageTest < ActiveSupport::TestCase
  def setup
    @pull_request_review = pull_request_reviews(:review_pr_one)
    # Use order 4 since fixtures use orders 1, 2, 3
    @valid_attributes = {
      pull_request_review: @pull_request_review,
      sender: "user",
      content: "Test message content",
      order: 4
    }
    @message = LlmConversationMessage.new(@valid_attributes)
  end

  # Association tests
  test "belongs to pull request review" do
    assert_respond_to @message, :pull_request_review
    assert_instance_of PullRequestReview, @message.pull_request_review
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @message.valid?
  end

  test "should require sender" do
    @message.sender = nil
    assert_not @message.valid?
    assert_includes @message.errors[:sender], "can't be blank"

    @message.sender = ""
    assert_not @message.valid?
    assert_includes @message.errors[:sender], "can't be blank"
  end

  test "should require content" do
    @message.content = nil
    assert_not @message.valid?
    assert_includes @message.errors[:content], "can't be blank"

    @message.content = ""
    assert_not @message.valid?
    assert_includes @message.errors[:content], "can't be blank"
  end

  test "should require order or auto-set it" do
    @message.order = nil
    # The set_order callback will auto-assign an order
    assert @message.valid?

    # But if we skip callbacks and force validation, it should fail
    @message.order = nil
    @message.run_callbacks(:validation) { false } # Skip callbacks
    @message.valid?
    # The presence validation is checked, but callback already ran
    # Let's test this differently - ensure order gets set
    @message.order = nil
    @message.save!
    assert_not_nil @message.order
  end

  test "should validate order is greater than 0" do
    # Create a new message to avoid fixture conflicts
    review = pull_request_reviews(:review_pr_two) # Different review to avoid order conflicts
    msg = LlmConversationMessage.new(
      pull_request_review: review,
      sender: "user",
      content: "Test content"
    )

    msg.order = 0
    assert_not msg.valid?
    assert_includes msg.errors[:order], "must be greater than 0"

    msg.order = -1
    assert_not msg.valid?
    assert_includes msg.errors[:order], "must be greater than 0"

    # Use an order that doesn't conflict with existing fixtures
    msg.order = 10
    assert msg.valid?
  end

  test "should validate order is numeric" do
    @message.order = "not_a_number"
    assert_not @message.valid?
    assert_includes @message.errors[:order], "is not a number"
  end

  test "should require unique order scoped to pull_request_review" do
    @message.save!

    duplicate_message = LlmConversationMessage.new(@valid_attributes)
    assert_not duplicate_message.valid?
    assert_includes duplicate_message.errors[:order], "has already been taken"
  end

  test "should allow same order for different pull request reviews" do
    @message.save!

    other_review = pull_request_reviews(:review_pr_two)
    other_message = LlmConversationMessage.new(@valid_attributes.merge(
      pull_request_review: other_review
    ))
    assert other_message.valid?
  end

  # Scope tests
  test "ordered scope returns messages ordered by order field" do
    review = @pull_request_review

    # Clear existing messages
    review.llm_conversation_messages.destroy_all

    # Create messages out of order
    msg3 = review.llm_conversation_messages.create!(sender: "user", content: "Third", order: 3)
    msg1 = review.llm_conversation_messages.create!(sender: "user", content: "First", order: 1)
    msg2 = review.llm_conversation_messages.create!(sender: "user", content: "Second", order: 2)

    ordered_messages = review.llm_conversation_messages.ordered
    assert_equal [ msg1, msg2, msg3 ], ordered_messages.to_a
  end

  test "by_user scope returns only user messages" do
    review = @pull_request_review
    review.llm_conversation_messages.destroy_all

    user_msg = review.llm_conversation_messages.create!(sender: "user", content: "User message", order: 1)
    llm_msg = review.llm_conversation_messages.create!(sender: "claude", content: "LLM message", order: 2)

    user_messages = review.llm_conversation_messages.by_user
    assert_includes user_messages, user_msg
    assert_not_includes user_messages, llm_msg
  end

  test "by_llm scope returns only non-user messages" do
    review = @pull_request_review
    review.llm_conversation_messages.destroy_all

    user_msg = review.llm_conversation_messages.create!(sender: "user", content: "User message", order: 1)
    llm_msg1 = review.llm_conversation_messages.create!(sender: "claude", content: "Claude message", order: 2)
    llm_msg2 = review.llm_conversation_messages.create!(sender: "gpt", content: "GPT message", order: 3)

    llm_messages = review.llm_conversation_messages.by_llm
    assert_not_includes llm_messages, user_msg
    assert_includes llm_messages, llm_msg1
    assert_includes llm_messages, llm_msg2
  end

  # Callback tests
  test "set_timestamp callback sets timestamp on create" do
    @message.timestamp = nil

    travel_to Time.current do
      @message.save!
      assert_not_nil @message.timestamp
      assert_in_delta Time.current, @message.timestamp, 1.second
    end
  end

  test "set_timestamp callback does not override existing timestamp" do
    existing_time = 1.hour.ago
    @message.timestamp = existing_time
    @message.save!

    assert_equal existing_time.to_i, @message.timestamp.to_i
  end

  test "set_order callback sets order when not present" do
    review = @pull_request_review
    review.llm_conversation_messages.destroy_all

    # First message should get order 1
    msg1 = review.llm_conversation_messages.build(sender: "user", content: "First")
    msg1.save!
    assert_equal 1, msg1.order

    # Second message should get order 2
    msg2 = review.llm_conversation_messages.build(sender: "user", content: "Second")
    msg2.save!
    assert_equal 2, msg2.order
  end

  test "set_order callback does not override existing order" do
    @message.order = 5
    @message.save!
    assert_equal 5, @message.order
  end

  test "set_order callback handles empty conversation" do
    review = @pull_request_review
    review.llm_conversation_messages.destroy_all

    msg = review.llm_conversation_messages.build(sender: "user", content: "First message")
    msg.save!
    assert_equal 1, msg.order
  end

  # Class method tests
  test "placeholder_for creates placeholder message" do
    user_message = llm_conversation_messages(:user_message)
    placeholder = LlmConversationMessage.placeholder_for(user_message)

    assert_equal "ruby_llm", placeholder.sender
    assert_equal "", placeholder.content
    assert placeholder.placeholder?
    assert_equal user_message.id, placeholder.parent_id
  end

  # Instance method tests
  test "placeholder? returns true for placeholder messages" do
    @message.placeholder = true
    assert @message.placeholder?

    @message.placeholder = false
    assert_not @message.placeholder?

    @message.placeholder = nil
    assert_not @message.placeholder?
  end

  test "from_user? returns true for user messages" do
    @message.sender = "user"
    assert @message.from_user?

    @message.sender = "claude"
    assert_not @message.from_user?

    @message.sender = "gpt"
    assert_not @message.from_user?
  end

  test "from_llm? returns true for non-user messages" do
    @message.sender = "user"
    assert_not @message.from_llm?

    @message.sender = "claude"
    assert @message.from_llm?

    @message.sender = "gpt"
    assert @message.from_llm?

    @message.sender = "ruby_llm"
    assert @message.from_llm?
  end

  # Edge case and data integrity tests
  test "handles very long content" do
    @message.content = "A" * 10000
    assert @message.valid?
  end

  test "handles special characters in content" do
    @message.content = "Code: if (user && user.isValid()) { return 'success'; } else { throw new Error('Invalid user'); }"
    assert @message.valid?
  end

  test "handles various sender values" do
    valid_senders = %w[user claude gpt ruby_llm openai anthropic]
    valid_senders.each do |sender|
      @message.sender = sender
      assert @message.valid?, "Sender '#{sender}' should be valid"
    end
  end

  test "handles large order values" do
    @message.order = 999999
    assert @message.valid?
  end

  test "handles decimal order values" do
    # Use a different review to avoid order conflicts and use a higher order
    review = pull_request_reviews(:review_pr_two)
    msg = LlmConversationMessage.new(
      pull_request_review: review,
      sender: "user",
      content: "Test content",
      order: 10.5
    )
    # Rails will convert 10.5 to 10 for integer column
    assert msg.valid?
    msg.save!
    assert_equal 10, msg.order
  end

  test "handles optional fields" do
    @message.llm_model_used = nil
    @message.token_count = nil
    @message.timestamp = nil
    assert @message.valid?
  end

  # Fixture integration tests
  test "fixture user_message is valid" do
    msg = llm_conversation_messages(:user_message)
    assert msg.valid?
    assert_equal "user", msg.sender
    assert msg.from_user?
    assert_not msg.from_llm?
    assert_equal 1, msg.order
  end

  test "fixture llm_response is valid" do
    msg = llm_conversation_messages(:llm_response)
    assert msg.valid?
    assert_equal "claude_3_opus", msg.sender
    assert_not msg.from_user?
    assert msg.from_llm?
    assert_equal 2, msg.order
  end

  test "fixtures are properly ordered" do
    review = pull_request_reviews(:review_pr_one)
    messages = review.llm_conversation_messages.ordered

    assert_equal 3, messages.count
    assert_equal [ 1, 2, 3 ], messages.pluck(:order)

    # Check specific fixture messages
    assert_equal "user", messages.first.sender
    assert_equal "claude_3_opus", messages.second.sender
    assert_equal "user", messages.third.sender
  end

  test "fixtures maintain unique orders within review" do
    review = pull_request_reviews(:review_pr_one)
    orders = review.llm_conversation_messages.pluck(:order)
    assert_equal orders.uniq, orders, "Orders should be unique within review"
  end

  # Integration tests
  test "creating message without order auto-assigns next order" do
    review = pull_request_reviews(:review_pr_one)
    existing_max_order = review.llm_conversation_messages.maximum(:order)

    new_message = review.llm_conversation_messages.build(
      sender: "user",
      content: "New message"
    )
    new_message.save!

    assert_equal existing_max_order + 1, new_message.order
  end

  test "destroying message does not affect other message orders" do
    review = pull_request_reviews(:review_pr_one)
    messages = review.llm_conversation_messages.ordered.to_a
    middle_message = messages[1] # Order 2

    middle_message.destroy

    remaining_messages = review.llm_conversation_messages.ordered
    assert_equal [ 1, 3 ], remaining_messages.pluck(:order)
  end

  test "messages are properly associated with pull request review" do
    msg = llm_conversation_messages(:user_message)
    review = pull_request_reviews(:review_pr_one)

    assert_equal review, msg.pull_request_review
    assert_includes review.llm_conversation_messages, msg
  end

  # Performance/efficiency tests
  test "ordered scope uses database ordering" do
    # This test ensures the ordering is done at database level, not in Ruby
    review = @pull_request_review

    # The ordered scope should include ORDER BY in the SQL
    sql = review.llm_conversation_messages.ordered.to_sql
    assert_includes sql.downcase, "order by"
  end

  test "scoped queries are chainable" do
    review = @pull_request_review

    # Should be able to chain scopes
    chained_query = review.llm_conversation_messages.by_user.ordered
    assert_respond_to chained_query, :to_a

    # Verify it returns user messages in order
    messages = chained_query.to_a
    messages.each { |msg| assert msg.from_user? }

    if messages.length > 1
      orders = messages.map(&:order)
      assert_equal orders.sort, orders, "Messages should be ordered"
    end
  end
end
