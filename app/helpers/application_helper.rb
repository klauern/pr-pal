module ApplicationHelper
  include MarkdownRenderer

  def safe_pr_link(pull_request_review)
    title = html_escape(pull_request_review.github_pr_title)
    url = safe_pr_url(pull_request_review.github_pr_url)

    link_to title, url, target: "_blank", class: "text-blue-600 hover:text-blue-800"
  end

  private

  def safe_pr_url(url)
    return "#" if url.blank?

    url_string = url.to_s
    if url_string.start_with?("https://github.com/", "http://github.com/")
      url_string
    else
      "#"
    end
  end
end
