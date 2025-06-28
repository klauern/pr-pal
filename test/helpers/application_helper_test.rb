require "test_helper"
require "minitest/mock"

class ApplicationHelperTest < ActionView::TestCase

  def setup
    @pull_request_review = pull_request_reviews(:one)
    # Set up mock data for the PR review
    @pull_request_review.define_singleton_method(:github_pr_title) { "Test PR Title" }
    @pull_request_review.define_singleton_method(:github_pr_url) { "https://github.com/owner/repo/pull/123" }
  end

  # markdown_to_html tests
  test "markdown_to_html should return empty string for blank content" do
    assert_equal "", markdown_to_html(nil)
    assert_equal "", markdown_to_html("")
    assert_equal "", markdown_to_html("   ")
  end

  test "markdown_to_html should convert simple markdown" do
    result = markdown_to_html("# Header\n\nThis is **bold** text.")
    # Check for header and bold elements (exact format may vary)
    assert_match %r{<h1.*>.*Header.*</h1>}, result
    assert_includes result, "<strong>bold</strong>"
    assert result.html_safe?
  end

  test "markdown_to_html should handle plain text" do
    result = markdown_to_html("Just plain text")
    assert_includes result, "Just plain text"
    assert result.html_safe?
  end

  test "markdown_to_html should handle line breaks" do
    result = markdown_to_html("Line 1\nLine 2")
    assert result.html_safe?
    # Should contain the text regardless of how line breaks are handled
    assert_includes result, "Line 1"
    assert_includes result, "Line 2"
  end

  test "markdown_to_html should be html_safe" do
    result = markdown_to_html("Any text")
    assert result.html_safe?
  end

  # Test the private safe_pr_url method through public interface by inspecting helper behavior
  test "safe_pr_url should allow valid github https urls" do
    # Test through the send method since it's private
    assert_equal "https://github.com/owner/repo/pull/123", send(:safe_pr_url, "https://github.com/owner/repo/pull/123")
  end

  test "safe_pr_url should allow valid github http urls" do  
    assert_equal "http://github.com/owner/repo/pull/123", send(:safe_pr_url, "http://github.com/owner/repo/pull/123")
  end

  test "safe_pr_url should reject invalid urls" do
    assert_equal "#", send(:safe_pr_url, "https://evil.com/bad-url")
    assert_equal "#", send(:safe_pr_url, "javascript:alert('xss')")
    assert_equal "#", send(:safe_pr_url, "ftp://github.com/owner/repo")
  end

  test "safe_pr_url should handle blank and nil urls" do
    assert_equal "#", send(:safe_pr_url, "")
    assert_equal "#", send(:safe_pr_url, nil)
    assert_equal "#", send(:safe_pr_url, "   ")
  end
end