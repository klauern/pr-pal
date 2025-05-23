class TabsController < ApplicationController
  def open_pr
    pr_id = params[:pr_id]
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs] << pr_id unless session[:open_pr_tabs].include?(pr_id)
    session[:active_tab] = pr_id
    render_sidebar_and_main
  end

  def close_pr
    pr_id = params[:pr_id]
    session[:open_pr_tabs] ||= []
    session[:open_pr_tabs].delete(pr_id)
    session[:active_tab] = session[:open_pr_tabs].last || "home"
    render_sidebar_and_main
  end

  def select_tab
    tab = params[:tab]
    session[:active_tab] = tab
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
      format.html { redirect_to root_path }
    end
  end
end
