require "net/http"
require "uri"
require "nokogiri"
require "reverse_markdown"

class WebContentTool < RubyLLM::Tool
  description "Fetches web content from a URL and converts it to markdown format"
  param :url, desc: "The URL to fetch content from (must be a valid HTTP/HTTPS URL)"

  def execute(url:)
    # Validate URL format
    begin
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        return "Error: Invalid URL format. Please provide a valid HTTP or HTTPS URL."
      end
    rescue URI::InvalidURIError
      return "Error: Invalid URL format. Please provide a valid HTTP or HTTPS URL."
    end

    # Set timeout and headers
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (compatible; WebContentTool/1.0)"
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    begin
      response = http.request(request)

      case response.code.to_i
      when 200
        convert_to_markdown(response.body, url)
      when 301, 302, 303, 307, 308
        redirect_url = response["location"]
        if redirect_url
          # Handle relative redirects
          redirect_uri = URI.join(url, redirect_url)
          "Redirected to: #{redirect_uri}. Please use the redirected URL."
        else
          "Error: Received redirect but no location header found."
        end
      when 404
        "Error: Page not found (404). Please check the URL and try again."
      when 403
        "Error: Access forbidden (403). The server denied access to this resource."
      when 500..599
        "Error: Server error (#{response.code}). The website is experiencing issues."
      else
        "Error: Received HTTP status #{response.code}. Unable to fetch content."
      end
    rescue Net::ReadTimeout, Net::OpenTimeout
      "Error: Request timed out. The website may be slow or unreachable."
    rescue Net::HTTPError => e
      "Error: HTTP error occurred: #{e.message}"
    rescue SocketError
      "Error: Unable to connect to the website. Please check the URL and your internet connection."
    rescue => e
      "Error: An unexpected error occurred: #{e.message}"
    end
  end

  private

  def convert_to_markdown(html_content, source_url)
    begin
      # Parse HTML with Nokogiri
      doc = Nokogiri::HTML(html_content)

      # Remove script and style elements
      doc.css("script, style, noscript").remove

      # Remove common navigation and footer elements
      doc.css("nav, header, footer, .navigation, .nav, .sidebar, .ads, .advertisement").remove

      # Try to find main content area
      main_content = doc.css("main, article, .content, .main-content, .post-content, .entry-content").first
      content_html = main_content ? main_content.to_html : doc.css("body").to_html

      # Convert to markdown using reverse_markdown
      markdown = ReverseMarkdown.convert(content_html, {
        unknown_tags: :bypass,
        github_flavored: true,
        whitespace: :remove
      })

      # Clean up excessive whitespace
      markdown = markdown.gsub(/\n{3,}/, "\n\n").strip

      # Add source attribution
      result = "# Web Content from #{source_url}\n\n"
      result += markdown

      # Limit content length to prevent overwhelming responses
      if result.length > 8000
        result = result[0..8000] + "\n\n[Content truncated due to length...]"
      end

      result

    rescue => e
      "Error: Failed to parse HTML content: #{e.message}"
    end
  end
end
