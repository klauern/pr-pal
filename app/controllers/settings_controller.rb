class SettingsController < ApplicationController
  include Authentication

  before_action :require_authentication

  def index
    @user = Current.user
    @llm_api_keys = @user.llm_api_keys.order(:llm_provider)
    @llm_providers = %w[openai anthropic]
    @preferred_provider = @user.default_llm_provider
    @preferred_model = @user.default_llm_model
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

  def llm
    @user = Current.user
    @llm_api_keys = @user.llm_api_keys.order(:llm_provider)
    @llm_providers = %w[openai anthropic]
    @preferred_provider = @user.default_llm_provider
    @preferred_model = @user.default_llm_model
  end

  def add_llm_api_key
    @user = Current.user
    key = @user.llm_api_keys.find_or_initialize_by(llm_provider: params[:llm_provider])
    key.api_key = params[:api_key]
    key.save!
    redirect_to settings_path, notice: "LLM API key saved."
  rescue => e
    redirect_to settings_path, alert: "Error saving LLM API key: #{e.message}"
  end

  def update_llm_api_key
    @user = Current.user
    key = @user.llm_api_keys.find_by(llm_provider: params[:llm_provider])
    if key&.update(api_key: params[:api_key])
      redirect_to settings_path, notice: "LLM API key updated."
    else
      redirect_to settings_path, alert: "Error updating LLM API key."
    end
  end

  def delete_llm_api_key
    @user = Current.user
    key = @user.llm_api_keys.find_by(llm_provider: params[:llm_provider])
    key&.destroy
    redirect_to settings_path, notice: "LLM API key deleted."
  end

  def update_llm_preferences
    @user = Current.user
    @user.default_llm_provider = params[:default_llm_provider]
    @user.default_llm_model = params[:default_llm_model]
    if @user.save
      redirect_to settings_path, notice: "LLM preferences updated."
    else
      redirect_to settings_path, alert: "Error updating LLM preferences."
    end
  end

  private

  def update_profile
    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully!"
    else
      set_llm_vars
      render :index, status: :unprocessable_entity
    end
  end

  def update_password
    if password_params[:password].blank?
      @user.errors.add(:password, "can't be blank")
      set_llm_vars
      render :index, status: :unprocessable_entity
    elsif @user.update(password_params)
      redirect_to settings_path, notice: "Password updated successfully!"
    else
      set_llm_vars
      render :index, status: :unprocessable_entity
    end
  end

  def update_github_token
    if @user.update(github_params)
      redirect_to settings_path, notice: "GitHub token updated successfully!"
    else
      set_llm_vars
      render :index, status: :unprocessable_entity
    end
  end

  def set_llm_vars
    @llm_api_keys = @user.llm_api_keys.order(:llm_provider)
    @llm_providers = %w[openai anthropic]
    @preferred_provider = @user.default_llm_provider
    @preferred_model = @user.default_llm_model
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
