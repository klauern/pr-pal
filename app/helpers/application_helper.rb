module ApplicationHelper
  def markdown_to_html(content)
    return "" if content.blank?

    begin
      require "commonmarker"

      # Use commonmarker to render markdown to HTML
      # The to_html method handles safe rendering by default
      doc = Commonmarker.to_html(content)
      doc.html_safe
    rescue LoadError
      # Fallback if commonmarker is not available
      html_escape(content).gsub("\n", "<br>").html_safe
    rescue => e
      # Fallback if markdown parsing fails
      Rails.logger.warn "Markdown parsing failed: #{e.message}"
      html_escape(content).gsub("\n", "<br>").html_safe
    end
  end

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
