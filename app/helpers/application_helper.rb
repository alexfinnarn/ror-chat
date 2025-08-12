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
    add_tailwind_classes(html, dark_mode: dark_mode).html_safe
  end

  private

  def add_tailwind_classes(html, dark_mode: false)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    # Style headings
    doc.css("h1").each { |h| h["class"] = "text-lg font-semibold mb-2 mt-4 first:mt-0" }
    doc.css("h2").each { |h| h["class"] = "text-base font-semibold mb-2 mt-3 first:mt-0" }
    doc.css("h3").each { |h| h["class"] = "text-sm font-semibold mb-2 mt-3 first:mt-0" }

    # Style paragraphs
    doc.css("p").each { |p| p["class"] = "mb-3 last:mb-0 leading-relaxed" }

    # Style lists
    doc.css("ul").each { |ul| ul["class"] = "list-disc pl-5 mb-3 space-y-1" }
    doc.css("ol").each { |ol| ol["class"] = "list-decimal pl-5 mb-3 space-y-1" }
    doc.css("li").each { |li| li["class"] = "leading-relaxed" }

    # Style text formatting
    doc.css("strong").each { |s| s["class"] = "font-semibold" }
    doc.css("em").each { |e| e["class"] = "italic" }

    # Style code
    code_bg = dark_mode ? "bg-white bg-opacity-20" : "bg-gray-100"
    doc.css("code").each { |c| c["class"] = "#{code_bg} px-1 py-0.5 rounded text-sm font-mono" }

    # Style code blocks
    pre_bg = dark_mode ? "bg-white bg-opacity-20" : "bg-gray-100"
    doc.css("pre").each do |pre|
      pre["class"] = "#{pre_bg} p-3 rounded-lg overflow-x-auto mb-3"
      pre.css("code").each { |c| c["class"] = "font-mono text-sm bg-transparent px-0 py-0" }
    end

    # Style blockquotes
    border_color = dark_mode ? "border-white border-opacity-30" : "border-gray-300"
    text_color = dark_mode ? "text-white text-opacity-80" : "text-gray-600"
    doc.css("blockquote").each { |bq| bq["class"] = "border-l-4 #{border_color} pl-4 my-3 #{text_color}" }

    # Style links
    link_color = dark_mode ? "text-blue-200 hover:text-blue-100" : "text-blue-600 hover:text-blue-500"
    doc.css("a").each { |a| a["class"] = "#{link_color} underline" }

    doc.to_html
  end
end
