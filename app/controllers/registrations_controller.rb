class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_url, alert: "Try again later." }
  layout "login", only: [ :new ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    begin
      if @user.save
        start_new_session_for @user
        redirect_to root_path, notice: "Welcome! Your account has been created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @user.errors.add(:email_address, "has already been taken")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
