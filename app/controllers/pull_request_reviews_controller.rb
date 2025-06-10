class PullRequestReviewsController < ApplicationController
  before_action :set_pull_request_review, only: [ :show, :update, :destroy, :sync ]

  def index
    @pull_request_reviews = Current.user.pull_request_reviews.in_progress.includes(:repository)
  end

  def show
    @pull_request_review.mark_as_viewed!
    
    # Trigger auto-sync if needed
    trigger_auto_sync_if_needed(@pull_request_review)
    
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
    
    # Trigger auto-sync if needed
    trigger_auto_sync_if_needed(@pull_request_review)
    
    @messages = @pull_request_review.llm_conversation_messages.ordered
    @new_message = @pull_request_review.llm_conversation_messages.build

    # Add this PR to the open tabs session
    add_pr_to_tabs(@pull_request_review.id)

    # Render the same view as the regular show action
    render :show
  end

  def sync
    respond_to do |format|
      begin
        # Use the data provider to sync the latest PR data
        repository = @pull_request_review.repository
        provider = DataProviders.pull_request_provider
        
        if provider.name == "GithubPullRequestDataProvider"
          # For GitHub provider, fetch latest data
          pr_data = provider.fetch_pr_details(
            repository.owner,
            repository.name, 
            @pull_request_review.github_pr_id,
            Current.user
          )
          
          pr_diff = provider.fetch_pr_diff(
            repository.owner,
            repository.name,
            @pull_request_review.github_pr_id,
            Current.user
          )
          
          # Update the review with latest data
          @pull_request_review.update!(
            github_pr_title: pr_data[:title],
            github_pr_url: pr_data[:html_url],
            last_synced_at: Time.current,
            pr_diff: pr_diff,
            sync_status: 'completed'
          )
          
          # Update the associated PullRequest if it exists
          if @pull_request_review.pull_request
            @pull_request_review.pull_request.update!(
              title: pr_data[:title],
              body: pr_data[:body],
              state: pr_data[:state],
              author: pr_data[:user],
              github_pr_url: pr_data[:html_url],
              github_updated_at: pr_data[:updated_at]
            )
          end
          
          success_message = "PR data synced successfully. Updated diff (#{pr_diff&.length || 0} characters)"
        else
          # For dummy provider, refresh the dummy data
          @pull_request_review.update!(
            pr_diff: provider.generate_dummy_pr_diff(repository, @pull_request_review.github_pr_id),
            last_synced_at: Time.current,
            sync_status: 'completed'
          )
          success_message = "Dummy PR data refreshed successfully"
        end
        
        format.html { redirect_to @pull_request_review, notice: success_message }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("flash-messages", 
              "<div class='bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4'>#{success_message}</div>"),
            turbo_stream.replace("sync_status", partial: "sync_status", locals: { pull_request_review: @pull_request_review })
          ]
        end
        format.json { render json: { status: "synced", message: success_message } }
        
      rescue => e
        error_message = "Failed to sync PR data: #{e.message}"
        Rails.logger.error "PR sync error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        format.html { redirect_to @pull_request_review, alert: error_message }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages",
            "<div class='bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4'>#{error_message}</div>")
        end
        format.json { render json: { status: "error", message: error_message } }
      end
    end
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

  def trigger_auto_sync_if_needed(pull_request_review)
    return unless pull_request_review.needs_auto_sync?
    
    Rails.logger.info "AUTO_SYNC: Triggering auto sync for PR review #{pull_request_review.id}"
    AutoSyncPrJob.perform_later(pull_request_review.id)
  rescue => e
    Rails.logger.error "AUTO_SYNC: Failed to enqueue auto sync job: #{e.message}"
    # Don't fail the page load if background sync fails to enqueue
  end
end
