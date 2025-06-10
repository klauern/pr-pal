# frozen_string_literal: true

require "ruby_llm"

# Service to manage LLM conversations using ruby_llm
class RubyLlmService
  def initialize(pull_request_review)
    @review = pull_request_review
    @history = @review.llm_conversation_messages.ordered
    
    # Build structured context for the LLM
    @context = build_structured_context
  end

  # Sends a user message to the LLM, including full conversation history
  def send_user_message(user_message)
    user = @review.user
    provider = user.preferred_llm_provider&.to_sym || :anthropic
    model = user.preferred_llm_model || "claude-3-sonnet-20241022"
    
    # Get the user's API key for this provider
    api_key = user.llm_api_keys.find_by(llm_provider: provider.to_s)&.api_key
    raise "No API key configured for #{provider}" unless api_key
    
    # Configure the chat with the user's API key - set the key in environment temporarily
    old_key = case provider
    when :anthropic
      old_anthropic_key = ENV["ANTHROPIC_API_KEY"]
      ENV["ANTHROPIC_API_KEY"] = api_key
      old_anthropic_key
    when :openai
      old_openai_key = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = api_key
      old_openai_key
    else
      raise "Unsupported provider: #{provider}"
    end
    
    begin
      chat = RubyLLM.chat(model: model, provider: provider)
    ensure
      # Restore the original key
      case provider
      when :anthropic
        ENV["ANTHROPIC_API_KEY"] = old_key
      when :openai
        ENV["OPENAI_API_KEY"] = old_key
      end
    end
    
    # Build the full prompt including context and conversation history
    prompt_parts = []
    
    # Add context as part of the conversation if available
    if @context.present?
      prompt_parts << "System: You are an expert code reviewer assistant. You have been provided with full information about a Pull Request including the code changes (diff). Use this information to provide helpful code review insights, identify potential issues, suggest improvements, and answer questions about the changes.\n\n#{@context}\n\nBased on this PR information, please help the user with their code review questions."
    end
    
    # Add conversation history
    history_text = @history.map do |msg|
      prefix = msg.sender == "user" ? "User:" : "Assistant:"
      "#{prefix} #{msg.content.strip}"
    end.join("\n")
    
    prompt_parts << history_text if history_text.present?
    prompt_parts << "User: #{user_message.strip}"
    prompt_parts << "Assistant:"
    
    prompt = prompt_parts.join("\n")

    response = chat.ask(prompt)

    @review.llm_conversation_messages.create!(
      sender: "ruby_llm",
      content: response.content,
      order: @review.llm_conversation_messages.maximum(:order).to_i + 1
    )

    response.content
  end

  private

  def build_structured_context
    context_parts = []
    
    # Add repository and PR metadata
    context_parts << "## Pull Request Information"
    context_parts << "Repository: #{@review.repository.full_name}"
    context_parts << "PR Number: ##{@review.github_pr_id}"
    context_parts << "Title: #{@review.github_pr_title}"
    context_parts << "URL: #{@review.github_pr_url}"
    context_parts << ""
    
    # Add user-provided context summary if available
    if @review.llm_context_summary.present?
      context_parts << "## Review Focus"
      context_parts << @review.llm_context_summary
      context_parts << ""
    end
    
    # Add the PR diff if available
    if @review.pr_diff.present?
      context_parts << "## Code Changes (Diff)"
      context_parts << "```diff"
      context_parts << @review.pr_diff
      context_parts << "```"
      context_parts << ""
    else
      context_parts << "## Code Changes"
      context_parts << "⚠️ PR diff is not available. Please ask the user to provide specific code snippets or descriptions of the changes they'd like reviewed."
      context_parts << ""
    end
    
    context_parts.join("\n")
  end
end
