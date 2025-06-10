class ProcessLlmResponseJob < ApplicationJob
  queue_as :default

  def perform(pull_request_review_id, user_message_id)
    Rails.logger.info "Processing LLM response for PR #{pull_request_review_id}, message #{user_message_id}"
    
    pull_request_review = PullRequestReview.find(pull_request_review_id)
    user_message = LlmConversationMessage.find(user_message_id)
    
    # Call the actual LLM service
    llm_service = RubyLlmService.new(pull_request_review)
    response_content = llm_service.send_user_message(user_message.content)
    
    # The LLM service creates the message, so we need to get the latest one
    llm_message = pull_request_review.llm_conversation_messages.by_llm.order(:order).last

    # Broadcast the LLM response to replace the placeholder
    placeholder_id = "llm_placeholder_#{user_message.id}"
    Rails.logger.info "Broadcasting LLM response to conversation_#{pull_request_review.id}, replacing target: #{placeholder_id}"
    
    # Set parent_id on the LLM message so the template uses the correct ID
    llm_message.parent_id = user_message.id
    
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{pull_request_review.id}",
      target: placeholder_id,
      partial: "llm_conversation_messages/message",
      locals: { message: llm_message }
    )
    Rails.logger.info "Broadcast completed successfully for target: #{placeholder_id}"
  rescue => e
    Rails.logger.error "Error processing LLM response: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Create error message in the database
    pull_request_review = PullRequestReview.find(pull_request_review_id) unless pull_request_review
    user_message = LlmConversationMessage.find(user_message_id) unless user_message
    
    error_message = pull_request_review.llm_conversation_messages.create!(
      sender: "system",
      content: "Sorry, there was an error processing your request. Please try again. Error: #{e.message}",
      timestamp: Time.current
    )
    
    # Set parent_id for consistent DOM targeting
    error_message.parent_id = user_message.id
    placeholder_id = "llm_placeholder_#{user_message.id}"
    
    Rails.logger.info "Broadcasting error message to replace target: #{placeholder_id}"
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{pull_request_review_id}", 
      target: placeholder_id,
      partial: "llm_conversation_messages/message",
      locals: { message: error_message }
    )
  end
end