class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def clean_orphaned_pr_tabs
    return unless session[:open_pr_tabs]

    valid_tabs = []
    session[:open_pr_tabs].each do |pr_tab|
      next if pr_tab.blank?
      numeric_id = pr_tab.to_s.gsub(/^pr_/, "")
      next if numeric_id.blank?

      # Check if the PR review still exists for current user
      if Current.user&.pull_request_reviews&.find_by(id: numeric_id)
        valid_tabs << pr_tab
      else
        Rails.logger.debug "Cleaning orphaned tab: #{pr_tab}"
      end
    end

    session[:open_pr_tabs] = valid_tabs.uniq
    Rails.logger.debug "Session tabs after cleanup: #{session[:open_pr_tabs]}"
  end
end
