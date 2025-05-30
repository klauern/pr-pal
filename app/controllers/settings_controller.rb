class SettingsController < ApplicationController
  include Authentication

  before_action :require_authentication

  def index
    @user = Current.user
  end

  def update
    @user = Current.user

    # Handle blank password by removing it from params
    cleaned_params = user_params
    if cleaned_params[:password].blank?
      cleaned_params = cleaned_params.except(:password, :password_confirmation)
    end

    if @user.update(cleaned_params)
      redirect_to settings_path, notice: "Settings updated successfully!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :github_token)
  end
end
