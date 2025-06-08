class PullRequestReviewsController < ApplicationController
  before_action :set_pull_request_review, only: [ :show, :update, :destroy ]

  def index
    @pull_request_reviews = Current.user.pull_request_reviews.in_progress.includes(:repository)
  end

  def show
    @pull_request_review.mark_as_viewed!
    @messages = @pull_request_review.llm_conversation_messages.ordered
    @new_message = @pull_request_review.llm_conversation_messages.build

    # Add this PR to the open tabs session
    add_pr_to_tabs(@pull_request_review.id)
  end

  def create
    @repository = Current.user.repositories.find(params[:repository_id])

    # Find or create the PullRequest record first
    pr_params = pull_request_review_params

    # Handle case where github_pr_id is nil or invalid
    if pr_params[:github_pr_id].present?
      @pull_request = @repository.pull_requests.find_or_create_by!(
        github_pr_id: pr_params[:github_pr_id]
      ) do |pr|
        pr.github_pr_url = pr_params[:github_pr_url]
        pr.title = pr_params[:github_pr_title]
        pr.state = "open" # default state
        pr.author = "unknown" # default author
      end
    else
      @pull_request = nil
    end

    @pull_request_review = @repository.pull_request_reviews.build(pr_params)
    @pull_request_review.user = Current.user
    @pull_request_review.pull_request = @pull_request

    respond_to do |format|
      if @pull_request_review.save
        # Add this PR to the open tabs session
        add_pr_to_tabs(@pull_request_review.id)

        @pull_request_reviews = Current.user.pull_request_reviews.in_progress.includes(:repository)
        format.html { redirect_to root_path(tab: "pull_request_reviews"), notice: "Pull request review started." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("main_content", partial: "layouts/main_content", locals: { tab: "pull_request_reviews" }),
            turbo_stream.prepend("flash-messages", "<div class='bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4'>Pull request review started.</div>")
          ]
        end
      else
        format.html { redirect_to root_path(tab: "repositories"), alert: "Failed to start review: #{@pull_request_review.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages",
            "<div class='bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4'>Failed to start review: #{@pull_request_review.errors.full_messages.join(', ')}</div>")
        end
      end
    end
  end

  def update
    respond_to do |format|
      if params[:action_type] == "complete"
        @pull_request_review.mark_as_completed!
        format.html { redirect_to root_path(tab: "pull_request_reviews"), notice: "Review marked as complete" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("main_content", partial: "layouts/main_content", locals: { tab: "pull_request_reviews" }),
            turbo_stream.prepend("flash-messages", "<div class='bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4'>Review marked as complete.</div>")
          ]
        end
        format.json { render json: { status: "completed", message: "Review marked as complete" } }
      elsif @pull_request_review.update(pull_request_review_params)
        format.html { redirect_to pull_request_review_path(@pull_request_review), notice: "Review updated successfully" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages",
            "<div class='bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4'>Review updated successfully.</div>")
        end
        format.json { render json: { status: "updated", message: "Review updated successfully" } }
      else
        format.html { redirect_to pull_request_review_path(@pull_request_review), alert: "Failed to update review: #{@pull_request_review.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages",
            "<div class='bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4'>Failed to update review: #{@pull_request_review.errors.full_messages.join(', ')}</div>")
        end
        format.json { render json: { status: "error", errors: @pull_request_review.errors.full_messages } }
      end
    end
  end

  def destroy
    @pull_request_review.destroy
    remove_pr_from_tabs(@pull_request_review.id)
    redirect_to root_path(tab: "pull_request_reviews"), notice: "Pull request review deleted."
  end

  def close_tab
    # Extract numeric ID from "pr_X" format if needed
    pr_id = params[:pr_id]
    pr_id = pr_id.gsub(/^pr_/, "") if pr_id.start_with?("pr_")

    remove_pr_from_tabs(pr_id)
    redirect_to root_path(tab: "pull_request_reviews")
  end

  def show_by_details
    begin
      # Use the data provider to fetch or create the PR review
      @repository, @pull_request_review = DataProviders.pull_request_provider.fetch_or_create_pr_review(
        owner: params[:repo_owner],
        name: params[:repo_name],
        pr_number: params[:pr_number],
        user: Current.user
      )
    rescue => e
      error_message = "Failed to create review: #{e.message}"
      if e.respond_to?(:record) && e.record && e.record.errors.any?
        error_message += ". Validation errors: #{e.record.errors.full_messages.join(', ')}"
      end
      redirect_to root_path, alert: error_message
      return
    end

    # Mark as viewed and set up instance variables for the view
    @pull_request_review.mark_as_viewed!
    @messages = @pull_request_review.llm_conversation_messages.ordered
    @new_message = @pull_request_review.llm_conversation_messages.build

    # Add this PR to the open tabs session
    add_pr_to_tabs(@pull_request_review.id)

    # Render the same view as the regular show action
    render :show
  end

  # Debug action to reset session tabs
  def reset_tabs
    session[:open_pr_tabs] = []
    redirect_to root_path, notice: "Tab session cleared!"
  end

  private

  def set_pull_request_review
    @pull_request_review = Current.user.pull_request_reviews.find(params[:id])
  end

  def pull_request_review_params
    params.require(:pull_request_review).permit(:github_pr_id, :github_pr_url, :github_pr_title, :llm_context_summary)
  end

  def add_pr_to_tabs(pr_id)
    pr_tab = "pr_#{pr_id}"
    session[:open_pr_tabs] ||= []

    # Debug before operation
    Rails.logger.debug "ADD_PR_TO_TABS: Before - pr_id: #{pr_id}, pr_tab: #{pr_tab}, current tabs: #{session[:open_pr_tabs]}"

    # Remove if already exists to avoid duplicates, then add to end
    session[:open_pr_tabs].delete(pr_tab)
    session[:open_pr_tabs] << pr_tab

    # Keep only last 5 tabs
    session[:open_pr_tabs] = session[:open_pr_tabs].last(5)

    Rails.logger.debug "ADD_PR_TO_TABS: After - Current tabs: #{session[:open_pr_tabs]}"
  end

  def remove_pr_from_tabs(pr_id)
    pr_tab = "pr_#{pr_id}"
    session[:open_pr_tabs] ||= []

    Rails.logger.debug "REMOVE_PR_FROM_TABS: Before - pr_id: #{pr_id}, pr_tab: #{pr_tab}, current tabs: #{session[:open_pr_tabs]}"

    session[:open_pr_tabs].delete(pr_tab)

    Rails.logger.debug "REMOVE_PR_FROM_TABS: After - Remaining tabs: #{session[:open_pr_tabs]}"
  end
end
