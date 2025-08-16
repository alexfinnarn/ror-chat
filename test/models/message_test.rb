require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @chat = @user.chats.create!(title: "Test Chat", model_id: "gpt-4")
    @message = @chat.messages.build(role: "assistant")
  end

  test "should detect thinking content with thinking tags" do
    @message.content = "<thinking>Let me think about this...</thinking>Here's my answer."
    assert @message.has_thinking_content?
  end

  test "should detect thinking content with think tags" do
    @message.content = "<think>Pondering the solution...</think>The solution is X."
    assert @message.has_thinking_content?
  end

  test "should not detect thinking content in regular messages" do
    @message.content = "This is a regular message without thinking."
    assert_not @message.has_thinking_content?
  end

  test "should not detect thinking content when content is empty" do
    @message.content = ""
    assert_not @message.has_thinking_content?
  end

  test "should extract thinking content from thinking tags" do
    @message.content = "<thinking>Deep thoughts here</thinking>Main answer"
    assert_equal "Deep thoughts here", @message.thinking_content
  end

  test "should extract thinking content from think tags" do
    @message.content = "<think>Analysis process</think>Final result"
    assert_equal "Analysis process", @message.thinking_content
  end

  test "should return nil thinking content for regular messages" do
    @message.content = "Regular message"
    assert_nil @message.thinking_content
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

    expected_thinking = "\nThis is a complex thought\nwith multiple lines\nand considerations\n"
    assert_equal expected_thinking.strip, @message.thinking_content.strip
    assert_equal "Here's the final answer.", @message.main_content
  end

  test "should handle empty thinking content" do
    @message.content = "<thinking></thinking>Main content here"
    assert_equal "", @message.thinking_content
    assert_equal "Main content here", @message.main_content
  end

  test "should handle multiple thinking blocks" do
    @message.content = "<thinking>First thought</thinking><thinking>Second thought</thinking>Answer"
    # Should match the first thinking block
    assert_equal "First thought", @message.thinking_content
  end

  test "build_streaming_content handles regular content" do
    content = "This is regular streaming content"
    result = @message.send(:build_streaming_content, content)

    # Should contain the markdown-rendered content
    assert_includes result, "This is regular streaming content"
  end

  test "build_streaming_content detects thinking pattern" do
    content = "<thinking>I need to analyze this"
    result = @message.send(:build_streaming_content, content)

    # Should contain thinking elements
    assert_includes result, "Thinking"
    assert_includes result, "details"
  end

  test "extract_streaming_thinking_content handles complete thinking" do
    content = "<thinking>Complete thought</thinking>Main answer"
    thinking, main, complete = @message.send(:extract_streaming_thinking_content, content)

    assert_equal "Complete thought", thinking
    assert_equal "Main answer", main
    assert complete
  end

  test "extract_streaming_thinking_content handles incomplete thinking" do
    content = "<thinking>Partial thought in progress"
    thinking, main, complete = @message.send(:extract_streaming_thinking_content, content)

    assert_equal "Partial thought in progress", thinking
    assert_equal "", main
    assert_not complete
  end

  test "extract_streaming_thinking_content handles think tags" do
    content = "<think>Analysis complete</think>Result here"
    thinking, main, complete = @message.send(:extract_streaming_thinking_content, content)

    assert_equal "Analysis complete", thinking
    assert_equal "Result here", main
    assert complete
  end

  test "extract_streaming_thinking_content handles no thinking content" do
    content = "Just regular content"
    thinking, main, complete = @message.send(:extract_streaming_thinking_content, content)

    assert_equal "", thinking
    assert_equal "Just regular content", main
    assert_not complete
  end

  test "has_thinking_pattern detects thinking tags" do
    assert @message.send(:has_thinking_pattern?, "<thinking>test")
    assert @message.send(:has_thinking_pattern?, "<think>test")
    assert_not @message.send(:has_thinking_pattern?, "regular content")
  end

  test "build_thinking_streaming_content shows ongoing indicator" do
    content = "<thinking>Partial thought"
    result = @message.send(:build_thinking_streaming_content, content)

    assert_includes result, "ongoing"
    assert_includes result, "open"
    assert_includes result, "animate-pulse"
  end

  test "build_thinking_streaming_content shows completed state" do
    content = "<thinking>Complete thought</thinking>Main content"
    result = @message.send(:build_thinking_streaming_content, content)

    assert_includes result, "Thinking..."
    assert_not_includes result, "ongoing"
    assert_not_includes result, "animate-pulse"
  end
end
