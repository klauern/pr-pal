class SettingsController < ApplicationController
  include Authentication

  before_action :require_authentication

  def index
    @user = Current.user
  end

  def update
    @user = Current.user
    form_type = params[:user][:form_type]

    case form_type
    when "profile"
      update_profile
    when "password"
      update_password
    when "github"
      update_github_token
    else
      redirect_to settings_path, alert: "Invalid form submission."
    end
  end

  private

  def update_profile
    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update_password
    if password_params[:password].blank?
      @user.errors.add(:password, "can't be blank")
      render :index, status: :unprocessable_entity
    elsif @user.update(password_params)
      redirect_to settings_path, notice: "Password updated successfully!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update_github_token
    if @user.update(github_params)
      redirect_to settings_path, notice: "GitHub token updated successfully!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def profile_params
    params.require(:user).permit(:email_address)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def github_params
    params.require(:user).permit(:github_token)
  end
end
