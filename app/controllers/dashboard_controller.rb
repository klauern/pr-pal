class DashboardController < ApplicationController
  def index
    if params[:tab]
      session[:active_tab] = params[:tab]
    end
    session[:active_tab] ||= "home"
    @active_tab = session[:active_tab]

    # Debug: Log current session state before cleanup
    Rails.logger.debug "BEFORE cleanup - Session tabs: #{session[:open_pr_tabs]}"

    # Clean up any orphaned PR tabs when loading the dashboard
    clean_orphaned_pr_tabs

    # Debug: Log session state after cleanup
    Rails.logger.debug "AFTER cleanup - Session tabs: #{session[:open_pr_tabs]}"
  end
end
