class LlmConversationMessagesController < ApplicationController
  before_action :set_pull_request_review

  def create
    @message = @pull_request_review.llm_conversation_messages.build(message_params)
    @message.sender = "user"

    if @message.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("conversation_messages",
            partial: "llm_conversation_messages/message",
            locals: { message: @message })
        end
        format.json { render json: { status: "success", message: "Message added" } }
      end
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

  private

  def set_pull_request_review
    @pull_request_review = Current.user.pull_request_reviews.find(params[:pull_request_review_id])
  end

  def message_params
    params.require(:llm_conversation_message).permit(:content)
  end
end
