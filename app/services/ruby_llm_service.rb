# frozen_string_literal: true

require "ruby_llm"

# Service to manage LLM conversations using ruby_llm
class RubyLlmService
  def initialize(pull_request_review)
    @review = pull_request_review
    @context = @review.llm_context_summary
    @history = @review.llm_conversation_messages.ordered
  end

  # Sends a user message to the LLM, including full conversation history
  def send_user_message(user_message)
    chat = RubyLLM.chat(model: "claude-3-opus", provider: :anthropic)
    chat = chat.with_instructions(@context) if @context.present?

    # Build the full prompt as a single string for Anthropic
    history_text = @history.map do |msg|
      prefix = msg.sender == "user" ? "User:" : "Assistant:"
      "#{prefix} #{msg.content.strip}"
    end.join("\n")
    prompt = "#{history_text}\nUser: #{user_message.strip}\nAssistant:"

    response = chat.ask(prompt)

    @review.llm_conversation_messages.create!(
      sender: "ruby_llm",
      content: response.content,
      order: @review.llm_conversation_messages.maximum(:order).to_i + 1
    )

    response.content
  end
end
