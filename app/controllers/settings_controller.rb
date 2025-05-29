class SettingsController < ApplicationController
  include Authentication

  before_action :require_authentication

  def index
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to settings_path, notice: "Settings updated successfully!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:github_token)
  end
end
