module ApplicationHelper
  def markdown_to_html(text, dark_mode: false)
    return "" if text.blank?

    # Configure Redcarpet with safe options for AI-generated content
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,        # Filter HTML tags for security
      no_links: false,          # Allow links
      no_images: false,         # Allow images
      no_styles: true,          # No inline styles
      safe_links_only: true,    # Only safe links
      with_toc_data: false,     # No table of contents data
      hard_wrap: true,          # Hard wrap lines
      xhtml: false              # HTML5 output
    )

    # Configure Markdown parser
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,                # Auto-link URLs
      tables: true,                  # Support tables
      fenced_code_blocks: true,      # Support ```code``` blocks
      strikethrough: true,           # Support ~~strikethrough~~
      superscript: true,             # Support ^superscript^
      underline: true,               # Support _underline_
      highlight: true,               # Support ==highlight==
      quote: false,                  # No quote syntax
      footnotes: false,              # No footnotes
      no_intra_emphasis: true,       # No emphasis inside words
      space_after_headers: true,     # Require space after headers
      disable_indented_code_blocks: false
    )

    html = markdown.render(text)
    content_tag(:div, html.html_safe, class: "markdown-content")
  end

end
