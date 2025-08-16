require "test_helper"

class ThinkingModeIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @chat = @user.chats.create!(title: "Integration Test Chat", model_id: "deepseekr1:8b")
  end

  test "message broadcast_append_chunk handles thinking content streaming" do
    message = @chat.messages.create!(role: "assistant", content: "")

    # Simulate streaming chunks
    chunks = [
      "<thinking>",
      "Let me think about this step by step",
      "</thinking>",
      "Here's my final answer"
    ]

    accumulated_content = ""
    chunks.each do |chunk|
      accumulated_content += chunk

      # Mock the broadcast to capture the formatted content
      formatted_content = message.send(:build_streaming_content, accumulated_content)

      case accumulated_content
      when "<thinking>"
        assert_includes formatted_content, "Thinking"
      when "<thinking>Let me think about this step by step"
        assert_includes formatted_content, "ongoing"
        assert_includes formatted_content, "Let me think about this step by step"
      when "<thinking>Let me think about this step by step</thinking>"
        assert_includes formatted_content, "Let me think about this step by step"
        assert_not_includes formatted_content, "ongoing"
      when "<thinking>Let me think about this step by step</thinking>Here's my final answer"
        assert_includes formatted_content, "Let me think about this step by step"
        assert_includes formatted_content, "Here's my final answer"
        assert_includes formatted_content, "details"
      end
    end
  end

  test "thinking content detection works with various formats" do
    test_cases = [
      {
        content: "<thinking>Simple thought</thinking>Answer",
        should_have_thinking: true,
        thinking_text: "Simple thought",
        main_text: "Answer"
      },
      {
        content: "<think>Alternative format</think>Response",
        should_have_thinking: true,
        thinking_text: "Alternative format",
        main_text: "Response"
      },
      {
        content: "No thinking content here",
        should_have_thinking: false,
        thinking_text: nil,
        main_text: "No thinking content here"
      },
      {
        content: "<thinking>\nMultiline\nthinking\n</thinking>\nMain response",
        should_have_thinking: true,
        thinking_text: "Multiline\nthinking",
        main_text: "Main response"
      }
    ]

    test_cases.each do |test_case|
      message = @chat.messages.create!(role: "assistant", content: test_case[:content])

      assert_equal test_case[:should_have_thinking], message.has_thinking_content?,
                   "Failed thinking detection for: #{test_case[:content]}"

      if test_case[:should_have_thinking]
        assert_equal test_case[:thinking_text].strip, message.thinking_content.strip,
                     "Failed thinking extraction for: #{test_case[:content]}"
      else
        assert_nil message.thinking_content,
                   "Should not have thinking content for: #{test_case[:content]}"
      end

      assert_equal test_case[:main_text].strip, message.main_content.strip,
                   "Failed main content extraction for: #{test_case[:content]}"
    end
  end

  test "streaming behavior transitions correctly through states" do
    message = @chat.messages.create!(role: "assistant", content: "")

    # Stage 1: Initial thinking tag
    content = "<thinking>"
    result = message.send(:build_streaming_content, content)
    assert_includes result, "Thinking"

    # Stage 2: Partial thinking content
    content = "<thinking>I need to analyze"
    result = message.send(:build_streaming_content, content)
    assert_includes result, "ongoing"
    assert_includes result, "I need to analyze"

    # Stage 3: More thinking content
    content = "<thinking>I need to analyze this problem carefully"
    result = message.send(:build_streaming_content, content)
    assert_includes result, "ongoing"
    assert_includes result, "this problem carefully"

    # Stage 4: Thinking complete
    content = "<thinking>I need to analyze this problem carefully</thinking>"
    result = message.send(:build_streaming_content, content)
    assert_not_includes result, "ongoing"
    assert_includes result, "this problem carefully"

    # Stage 5: Main content starts
    content = "<thinking>I need to analyze this problem carefully</thinking>The solution"
    result = message.send(:build_streaming_content, content)
    assert_includes result, "this problem carefully"
    assert_includes result, "The solution"
    assert_includes result, "details"
  end
end
