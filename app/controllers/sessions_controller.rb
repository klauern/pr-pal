class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }
  layout "login", only: [ :new ]

  def new
  end

  def create
    begin
      if user = User.authenticate_by(params.permit(:email_address, :password))
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to demo_login_path, alert: "Try another email address or password."
      end
    rescue ArgumentError
      # Handle malformed parameters (missing password, etc.)
      redirect_to demo_login_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    # Clear PR tabs on logout
    session[:open_pr_tabs] = nil
    redirect_to root_path
  end
end
