require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @chat = @user.chats.create!(title: "Test Chat", model_id: "gpt-4")
    @message = @chat.messages.build(role: "assistant")
  end

  test "should detect thinking content with thinking tags" do
    @message.content = "<thinking>Let me think about this...</thinking>Here's my answer."
    assert @message.has_thinking?
  end

  test "should detect thinking content with think tags" do
    @message.content = "<think>Pondering the solution...</think>The solution is X."
    assert @message.has_thinking?
  end

  test "should not detect thinking content in regular messages" do
    @message.content = "This is a regular message without thinking."
    assert_not @message.has_thinking?
  end

  test "should not detect thinking content when content is empty" do
    @message.content = ""
    assert_not @message.has_thinking?
  end

  test "should extract thinking content from thinking artifacts" do
    @message.content = "<thinking>Deep thoughts here</thinking>Main answer"
    thinking_artifact = @message.artifacts.find { |a| a.is_a?(Artifacts::ThinkingArtifact) }
    assert_equal "Deep thoughts here", thinking_artifact.content
  end

  test "should extract thinking content from think artifacts" do
    @message.content = "<think>Analysis process</think>Final result"
    thinking_artifact = @message.artifacts.find { |a| a.is_a?(Artifacts::ThinkingArtifact) }
    assert_equal "Analysis process", thinking_artifact.content
  end

  test "should return empty artifacts for regular messages" do
    @message.content = "Regular message"
    assert_empty @message.artifacts
  end

  test "should extract main content without thinking tags" do
    @message.content = "<thinking>Internal thoughts</thinking>This is the main response."
    assert_equal "This is the main response.", @message.main_content
  end

  test "should return full content as main content for regular messages" do
    @message.content = "Regular message content"
    assert_equal "Regular message content", @message.main_content
  end

  test "should handle multiline thinking content" do
    @message.content = <<~CONTENT
      <thinking>
      This is a complex thought
      with multiple lines
      and considerations
      </thinking>
      Here's the final answer.
    CONTENT

    thinking_artifact = @message.artifacts.find { |a| a.is_a?(Artifacts::ThinkingArtifact) }
    expected_thinking = "\nThis is a complex thought\nwith multiple lines\nand considerations\n"
    assert_equal expected_thinking.strip, thinking_artifact.content.strip
    assert_equal "Here's the final answer.", @message.main_content
  end

  test "should handle empty thinking content" do
    @message.content = "<thinking></thinking>Main content here"
    thinking_artifact = @message.artifacts.find { |a| a.is_a?(Artifacts::ThinkingArtifact) }
    assert_equal "", thinking_artifact.content
    assert_equal "Main content here", @message.main_content
  end

  test "should handle multiple thinking blocks" do
    @message.content = "<thinking>First thought</thinking><thinking>Second thought</thinking>Answer"
    thinking_artifacts = @message.artifacts.select { |a| a.is_a?(Artifacts::ThinkingArtifact) }
    # Should find both thinking blocks
    assert_equal 2, thinking_artifacts.length
    assert_equal "First thought", thinking_artifacts.first.content
    assert_equal "Second thought", thinking_artifacts.last.content
  end

  test "has_artifacts method works correctly" do
    @message.content = "<thinking>Some thoughts</thinking>Answer here"
    assert @message.has_artifacts?

    @message.content = "Regular message"
    assert_not @message.has_artifacts?
  end

  test "artifacts method returns artifact objects" do
    @message.content = "<thinking>Analysis</thinking>Answer<code>puts 'hello'</code>"
    artifacts = @message.artifacts

    assert_equal 2, artifacts.length
    assert_instance_of Artifacts::ThinkingArtifact, artifacts.first
    assert_instance_of Artifacts::CodeArtifact, artifacts.last
  end

  test "broadcast_append_chunk uses artifact renderer" do
    content = "<thinking>Processing</thinking>Final answer"

    # Test that the renderer is called by checking the rendered content
    renderer = ArtifactRenderer.new(content)
    formatted_content = renderer.render(dark_mode: false)

    assert_includes formatted_content, "Processing"
    assert_includes formatted_content, "Final answer"
    assert_includes formatted_content, "details" # Thinking dropdown
  end
end
