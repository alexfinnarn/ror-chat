require "test_helper"
require_relative "../../app/lib/web_content_tool"

class WebContentToolTest < ActiveSupport::TestCase
  def setup
    @tool = WebContentTool.new
  end

  test "tool has correct description" do
    assert_equal "Fetches web content from a URL and converts it to markdown format", @tool.class.description
  end

  test "tool validates invalid URLs" do
    result = @tool.execute(url: "not-a-url")
    assert_includes result, "Error: Invalid URL format"
  end

  test "tool validates non-HTTP URLs" do
    result = @tool.execute(url: "ftp://example.com")
    assert_includes result, "Error: Invalid URL format"
  end

  test "tool handles network errors gracefully" do
    # Test with a non-existent domain
    result = @tool.execute(url: "https://this-domain-should-not-exist-12345.com")
    assert_includes result, "Error:"
  end

  # Note: We're not testing actual HTTP requests in unit tests
  # to avoid external dependencies and network flakiness
end