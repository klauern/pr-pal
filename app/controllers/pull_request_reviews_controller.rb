class PullRequestReviewsController < ApplicationController
  before_action :set_pull_request_review, only: [ :show, :update, :destroy ]

  def index
    @pull_request_reviews = Current.user.pull_request_reviews.in_progress.includes(:repository)
  end

  def show
    @pull_request_review.mark_as_viewed!
    @messages = @pull_request_review.llm_conversation_messages.ordered
    @new_message = @pull_request_review.llm_conversation_messages.build
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
    redirect_to root_path(tab: "pull_request_reviews"), notice: "Pull request review deleted."
  end

  private

  def set_pull_request_review
    @pull_request_review = Current.user.pull_request_reviews.find(params[:id])
  end

  def pull_request_review_params
    params.require(:pull_request_review).permit(:github_pr_id, :github_pr_url, :github_pr_title, :llm_context_summary)
  end
end
