class LlmConversationMessagesController < ApplicationController
  before_action :set_pull_request_review

  def create
    @message = @pull_request_review.llm_conversation_messages.build(message_params)
    @message.sender = "user"

    if @message.save
      # Prepare a placeholder for the LLM response
      placeholder = LlmConversationMessage.placeholder_for(@message)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("conversation_messages",
              partial: "llm_conversation_messages/message",
              locals: { message: @message }),
            turbo_stream.append("conversation_messages",
              partial: "llm_conversation_messages/message",
              locals: { message: placeholder }),
            turbo_stream.replace("message_form",
              partial: "pull_request_reviews/message_form",
              locals: { pull_request_review: @pull_request_review, new_message: @pull_request_review.llm_conversation_messages.build })
          ]
        end
        format.json { render json: { status: "success", message: "Message added" } }
      end

      # Process LLM response in a background job to avoid blocking
      ProcessLlmResponseJob.perform_later(@pull_request_review.id, @message.id)
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("message_form",
            partial: "pull_request_reviews/message_form",
            locals: { pull_request_review: @pull_request_review, new_message: @message })
        end
        format.json { render json: { status: "error", errors: @message.errors.full_messages } }
      end
    end
  end

  def reset
    @pull_request_review.llm_conversation_messages.destroy_all
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("conversation_messages", partial: "llm_conversation_messages/empty")
      end
      format.json { render json: { status: "success", message: "Conversation reset" } }
    end
  end

  private

  def set_pull_request_review
    @pull_request_review = Current.user.pull_request_reviews.find(params[:pull_request_review_id])
  end

  def message_params
    params.require(:llm_conversation_message).permit(:content)
  end
end
