class DashboardController < ApplicationController
  def index
    if params[:tab]
      session[:active_tab] = params[:tab]
    end
    session[:active_tab] ||= "home"
    @active_tab = session[:active_tab]
  end
end
