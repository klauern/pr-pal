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

    @pull_request_review = @repository.pull_request_reviews.build(pull_request_review_params)
    @pull_request_review.user = Current.user

    if @pull_request_review.save
      redirect_to root_path(tab: "pull_request_reviews"), notice: "Pull request review started."
    else
      redirect_to root_path(tab: "repositories"), alert: "Failed to start review: #{@pull_request_review.errors.full_messages.join(', ')}"
    end
  end

  def update
    if params[:action_type] == "complete"
      @pull_request_review.mark_as_completed!
      render json: { status: "completed", message: "Review marked as complete" }
    elsif @pull_request_review.update(pull_request_review_params)
      render json: { status: "updated", message: "Review updated successfully" }
    else
      render json: { status: "error", errors: @pull_request_review.errors.full_messages }
    end
  end

  def destroy
    @pull_request_review.destroy
    remove_pr_from_tabs(@pull_request_review.id)
    redirect_to root_path(tab: "pull_request_reviews"), notice: "Pull request review deleted."
  end

  def close_tab
    pr_id = params[:pr_id]
    remove_pr_from_tabs(pr_id)
    redirect_to root_path(tab: "pull_request_reviews")
  end

  def show_by_details
    # Find or create repository
    @repository = Current.user.repositories.find_or_create_by(
      owner: params[:repo_owner],
      name: params[:repo_name]
    )

    # Find or create pull request review
    @pull_request_review = @repository.pull_request_reviews.find_or_initialize_by(
      github_pr_id: params[:pr_number],
      user: Current.user
    )

    # If this is a new review, set default values
    if @pull_request_review.new_record?
      @pull_request_review.assign_attributes(
        github_pr_title: "Review for PR ##{params[:pr_number]} in #{@repository.full_name}",
        github_pr_url: "#{@repository.github_url}/pull/#{params[:pr_number]}",
        status: "in_progress"
      )

      unless @pull_request_review.save
        redirect_to root_path, alert: "Failed to create review: #{@pull_request_review.errors.full_messages.join(', ')}"
        return
      end
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

  private

  def set_pull_request_review
    @pull_request_review = Current.user.pull_request_reviews.find(params[:id])
  end

  def pull_request_review_params
    params.require(:pull_request_review).permit(:github_pr_id, :github_pr_url, :github_pr_title, :llm_context_summary)
  end

  def add_pr_to_tabs(pr_id)
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs] << pr_id.to_s unless session[:open_pr_tabs].include?(pr_id.to_s)
    session[:open_pr_tabs] = session[:open_pr_tabs].last(5) # Keep only last 5 tabs
  end

  def remove_pr_from_tabs(pr_id)
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs].delete(pr_id.to_s)
  end
end
