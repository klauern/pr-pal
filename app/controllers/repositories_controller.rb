class RepositoriesController < ApplicationController
  before_action :set_repository, only: [ :destroy ]

  def index
    @repositories = Current.user.repositories.order(:owner, :name)
    @repository = Repository.new
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
    @repository.destroy
    @repositories = Current.user.repositories.order(:owner, :name)

    respond_to do |format|
      format.html { redirect_to root_path(tab: "repositories"), notice: "Repository was successfully removed." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("repositories_list", partial: "repositories/list", locals: { repositories: @repositories })
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
