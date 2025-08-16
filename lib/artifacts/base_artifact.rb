module Artifacts
  class BaseArtifact
    attr_reader :tag, :content, :attributes, :complete

    def initialize(tag:, content:, attributes: {}, complete: true)
      @tag = tag
      @content = content
      @attributes = attributes
      @complete = complete
    end

    # Pattern that identifies this artifact type
    def self.pattern
      raise NotImplementedError, "Subclasses must define a pattern method"
    end

    # Priority for artifact matching (lower numbers = higher priority)
    def self.priority
      100
    end

    # Check if this artifact type can handle the given content
    def self.handles?(content)
      content.match?(pattern)
    end

    # Extract artifact from content starting at the given match
    def self.extract_from_match(content, match)
      tag_name = extract_tag_name(match)
      closing_pattern = build_closing_pattern(tag_name)

      closing_match = content.match(closing_pattern, match.end(0))

      if closing_match
        # Complete artifact
        artifact_content = content[match.end(0)...closing_match.begin(0)].strip
        complete = true
      else
        # Incomplete artifact (still streaming)
        artifact_content = content[match.end(0)..-1].strip
        complete = false
      end

      new(
        tag: tag_name,
        content: artifact_content,
        attributes: extract_attributes(match[0]),
        complete: complete
      )
    end

    # Render the artifact to HTML
    def render(dark_mode: false)
      raise NotImplementedError, "Subclasses must implement render method"
    end

    # Default tag name extraction from match
    def self.extract_tag_name(match)
      # Override in subclasses if needed
      match[1] if match.captures.any?
    end

    # Default closing pattern building
    def self.build_closing_pattern(tag_name)
      /<\/#{Regexp.escape(tag_name)}>/
    end

    # Extract attributes from opening tag
    def self.extract_attributes(opening_tag)
      attrs = {}
      opening_tag.scan(/(\w+)=["']([^"']+)["']/) do |key, value|
        attrs[key.to_sym] = value
      end
      attrs
    end

    protected

    def markdown_to_html(content, dark_mode: false)
      ApplicationController.helpers.markdown_to_html(content, dark_mode: dark_mode)
    end

    def escape_html(content)
      ERB::Util.html_escape(content)
    end
  end
end
