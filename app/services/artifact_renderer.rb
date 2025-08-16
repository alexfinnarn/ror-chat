class ArtifactRenderer
  def initialize(content)
    @content = content
    @parsed_result = Artifacts::ArtifactRegistry.parse_artifacts(content)
  end

  def render(dark_mode: false)
    html_parts = []

    # Render each artifact
    @parsed_result[:artifacts].each do |artifact|
      html_parts << artifact.render(dark_mode: dark_mode)
    end

    # Add any remaining non-artifact content
    if @parsed_result[:remaining_content].present?
      html_parts << ApplicationController.helpers.markdown_to_html(@parsed_result[:remaining_content], dark_mode: dark_mode)
    end

    html_parts.join.html_safe
  end

  def has_artifacts?
    @parsed_result[:artifacts].any?
  end

  def has_thinking?
    @parsed_result[:artifacts].any? { |artifact| artifact.is_a?(Artifacts::ThinkingArtifact) }
  end

  def artifacts
    @parsed_result[:artifacts]
  end

  def remaining_content
    @parsed_result[:remaining_content]
  end
end
