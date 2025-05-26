class TabsController < ApplicationController
  def open_pr
    pr_id = params[:pr_id]
    pr_tab = "pr_#{pr_id}"
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs] << pr_tab unless session[:open_pr_tabs].include?(pr_tab)
    session[:active_tab] = pr_tab
    render_sidebar_and_main
  end

  def close_pr
    pr_tab = params[:pr_id] # This will be like "pr_1", "pr_2", etc.
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs].delete(pr_tab)
    session[:active_tab] = session[:open_pr_tabs].last || "home"
    render_sidebar_and_main
  end

  def select_tab
    tab = params[:tab]
    session[:active_tab] = tab

    # If opening a PR review tab, add it to open tabs
    if tab.match(/^pr_(\d+)$/)
      session[:open_pr_tabs] ||= []
      session[:open_pr_tabs] << tab unless session[:open_pr_tabs].include?(tab)
    end

    render_sidebar_and_main
  end

  private

  def render_sidebar_and_main
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("sidebar", partial: "layouts/sidebar"),
          turbo_stream.replace("main_content", partial: "layouts/main_content", locals: { tab: session[:active_tab] })
        ]
      end
      format.html do
        render turbo_stream: [
          turbo_stream.replace("sidebar", partial: "layouts/sidebar"),
          turbo_stream.replace("main_content", partial: "layouts/main_content", locals: { tab: session[:active_tab] })
        ]
      end
    end
  end
end
