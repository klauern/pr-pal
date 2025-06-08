class RepositoriesController < ApplicationController
  before_action :set_repository, only: [ :show, :destroy, :sync ]

  def index
    @repositories = Current.user.repositories.order(:owner, :name)
    @repository = Repository.new
  end

  def show
    show_all = params[:show] == "all"
    @pull_requests = if show_all
      @repository.pull_requests.by_recent
    else
      @repository.pull_requests.open.by_recent
    end
    @show_all_prs = show_all
    @pull_request_reviews = @repository.pull_request_reviews.order(:github_pr_id)
  end

  def new
    @repository = Current.user.repositories.build
  end

  def create
    @repository = Current.user.repositories.build(repository_params)

    respond_to do |format|
      if @repository.save
        @repositories = Current.user.repositories.order(:owner, :name)
        format.html { redirect_to root_path(tab: "repositories"), notice: "Repository was successfully added." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("repository_form", partial: "repositories/form", locals: { repository: Repository.new }),
            turbo_stream.replace("repositories_list", partial: "repositories/list", locals: { repositories: @repositories })
          ]
        end
      else
        @repositories = Current.user.repositories.order(:owner, :name)
        format.html { render :index, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("repository_form", partial: "repositories/form", locals: { repository: @repository })
        end
      end
    end
  end

  def destroy
    # Clean up open PR tabs before destroying repository
    affected_pr_ids = @repository.pull_request_reviews.pluck(:id)
    affected_tabs = affected_pr_ids.map { |id| "pr_#{id}" }

    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs] -= affected_tabs

    # If the current active tab is being removed, fall back to safe default
    if affected_tabs.include?(session[:active_tab])
      session[:active_tab] = session[:open_pr_tabs].last || "home"
    end

    @repository.destroy
    @repositories = Current.user.repositories.order(:owner, :name)

    respond_to do |format|
      format.html { redirect_to root_path(tab: "repositories"), notice: "Repository was successfully removed." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("repositories_list", partial: "repositories/list", locals: { repositories: @repositories }),
          turbo_stream.replace("sidebar", partial: "layouts/sidebar")
        ]
      end
    end
  end

  def sync
    PullRequestSyncJob.perform_later(@repository.id)

    respond_to do |format|
      format.html { redirect_to @repository, notice: "Repository sync started for #{@repository.full_name}. Pull requests will be updated in the background." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("flash_messages", partial: "shared/flash_message",
          locals: { type: "notice", message: "Repository sync started for #{@repository.full_name}. Pull requests will be updated in the background." })
      end
    end
  end

  def sync_all
    PullRequestSyncJob.sync_user_repositories(Current.user)

    respond_to do |format|
      format.html { redirect_to repositories_path, notice: "Sync started for all repositories. Pull requests will be updated in the background." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("flash_messages", partial: "shared/flash_message",
          locals: { type: "notice", message: "Sync started for all repositories. Pull requests will be updated in the background." })
      end
    end
  end

  private

  def set_repository
    @repository = Current.user.repositories.find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:owner, :name)
  end
end
