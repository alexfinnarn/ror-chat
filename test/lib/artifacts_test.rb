require "test_helper"

class ArtifactsTest < ActiveSupport::TestCase
  def setup
    # Clear registry for clean tests
    Artifacts::ArtifactRegistry.clear!
    # Re-register our artifacts
    Artifacts::ArtifactRegistry.register(Artifacts::ThinkingArtifact)
    Artifacts::ArtifactRegistry.register(Artifacts::CodeArtifact)
    Artifacts::ArtifactRegistry.register(Artifacts::ToolUseArtifact)
  end

  test "ArtifactRegistry registers artifacts" do
    assert_includes Artifacts::ArtifactRegistry.artifacts, Artifacts::ThinkingArtifact
    assert_includes Artifacts::ArtifactRegistry.artifacts, Artifacts::CodeArtifact
    assert_includes Artifacts::ArtifactRegistry.artifacts, Artifacts::ToolUseArtifact
  end

  test "ArtifactRegistry finds handlers for thinking content" do
    content = "<thinking>test content</thinking>"
    handlers = Artifacts::ArtifactRegistry.find_handlers(content)
    assert_includes handlers, Artifacts::ThinkingArtifact
  end

  test "ArtifactRegistry finds handlers for code content" do
    content = "<code>test code</code>"
    handlers = Artifacts::ArtifactRegistry.find_handlers(content)
    assert_includes handlers, Artifacts::CodeArtifact
  end

  test "ArtifactRegistry parses thinking artifacts" do
    content = "<thinking>Deep thoughts</thinking>Regular content"
    result = Artifacts::ArtifactRegistry.parse_artifacts(content)

    assert_equal 1, result[:artifacts].length
    artifact = result[:artifacts].first
    assert_instance_of Artifacts::ThinkingArtifact, artifact
    assert_equal "Deep thoughts", artifact.content
    assert_equal "Regular content", result[:remaining_content]
  end

  test "ArtifactRegistry parses code artifacts" do
    content = '<code language="ruby">puts "hello"</code>More content'
    result = Artifacts::ArtifactRegistry.parse_artifacts(content)

    assert_equal 1, result[:artifacts].length
    artifact = result[:artifacts].first
    assert_instance_of Artifacts::CodeArtifact, artifact
    assert_equal 'puts "hello"', artifact.content
    assert_equal "ruby", artifact.attributes[:language]
    assert_equal "More content", result[:remaining_content]
  end

  test "ArtifactRegistry handles multiple artifacts" do
    content = "<thinking>Analysis</thinking>Some text<code>code here</code>Final text"
    result = Artifacts::ArtifactRegistry.parse_artifacts(content)

    assert_equal 2, result[:artifacts].length
    assert_instance_of Artifacts::ThinkingArtifact, result[:artifacts].first
    assert_instance_of Artifacts::CodeArtifact, result[:artifacts].last
    assert_equal "Some textFinal text", result[:remaining_content]
  end

  test "ArtifactRegistry handles incomplete artifacts" do
    content = "<thinking>Partial thought"
    result = Artifacts::ArtifactRegistry.parse_artifacts(content)

    assert_equal 1, result[:artifacts].length
    artifact = result[:artifacts].first
    assert_instance_of Artifacts::ThinkingArtifact, artifact
    assert_equal "Partial thought", artifact.content
    assert_not artifact.complete
  end

  test "ThinkingArtifact renders complete thinking" do
    artifact = Artifacts::ThinkingArtifact.new(
      tag: "thinking",
      content: "Deep analysis here",
      complete: true
    )

    rendered = artifact.render
    assert_includes rendered, "Thinking..."
    assert_includes rendered, "Deep analysis here"
    assert_includes rendered, "details"
    assert_not_includes rendered, "ongoing"
  end

  test "ThinkingArtifact renders incomplete thinking" do
    artifact = Artifacts::ThinkingArtifact.new(
      tag: "thinking",
      content: "Partial thought",
      complete: false
    )

    rendered = artifact.render
    assert_includes rendered, "ongoing"
    assert_includes rendered, "Partial thought"
    assert_includes rendered, "animate-pulse"
    assert_includes rendered, "open"
  end

  test "CodeArtifact renders with language" do
    artifact = Artifacts::CodeArtifact.new(
      tag: "code",
      content: 'puts "hello world"',
      attributes: { language: "ruby" },
      complete: true
    )

    rendered = artifact.render
    assert_includes rendered, "RUBY"
    assert_includes rendered, 'puts "hello world"'
    assert_includes rendered, "Copy"
  end

  test "ArtifactRenderer handles mixed content" do
    content = "Starting text<thinking>My thoughts</thinking>Middle text<code>some code</code>End text"
    renderer = ArtifactRenderer.new(content)

    assert renderer.has_artifacts?
    assert renderer.has_thinking?
    assert_equal 2, renderer.artifacts.length

    rendered = renderer.render
    assert_includes rendered, "Starting text"
    assert_includes rendered, "My thoughts"
    assert_includes rendered, "Middle text"
    assert_includes rendered, "some code"
    assert_includes rendered, "End text"
  end

  test "ArtifactRenderer handles no artifacts" do
    content = "Just regular text with no artifacts"
    renderer = ArtifactRenderer.new(content)

    assert_not renderer.has_artifacts?
    assert_not renderer.has_thinking?
    assert_equal 0, renderer.artifacts.length

    rendered = renderer.render
    assert_includes rendered, "Just regular text with no artifacts"
  end
end
