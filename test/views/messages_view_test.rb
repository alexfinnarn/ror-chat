require "test_helper"

class MessagesViewTest < ActionView::TestCase
  def setup
    @user = users(:one)
    @chat = @user.chats.create!(title: "Test Chat", model_id: "gpt-4")
  end

  test "renders regular message without thinking content" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "This is a regular response without thinking."
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "This is a regular response without thinking."
    assert_not_includes rendered, "details"
    assert_not_includes rendered, "Thinking"
  end

  test "renders message with thinking content in dropdown" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "<thinking>Let me analyze this problem step by step.</thinking>The answer is 42."
    )

    rendered = render partial: "messages/message", locals: { message: message }

    # Should include thinking dropdown
    assert_includes rendered, "artifact-thinking"
    assert_includes rendered, "Thinking..."
    assert_includes rendered, "Let me analyze this problem step by step."

    # Should include main content
    assert_includes rendered, "The answer is 42."

    # Should have proper structure
    assert_includes rendered, "summary"
    assert_includes rendered, "cursor-pointer"
  end

  test "renders user message correctly" do
    message = @chat.messages.create!(
      role: "user",
      content: "What is the meaning of life?"
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "What is the meaning of life?"
    assert_includes rendered, "bg-blue-600"
    assert_includes rendered, "justify-end"
    assert_not_includes rendered, "details" # User messages don't have thinking
  end

  test "renders empty message with thinking indicator" do
    message = @chat.messages.create!(
      role: "assistant",
      content: ""
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "Thinking..."
    assert_includes rendered, "text-gray-500"
  end

  test "renders message with think tags" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "<think>Processing the request...</think>Here's the result."
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "artifact-thinking"
    assert_includes rendered, "Processing the request..."
    assert_includes rendered, "Here's the result."
  end

  test "renders message with multiline thinking content" do
    message = @chat.messages.create!(
      role: "assistant",
      content: <<~CONTENT
        <thinking>
        First, I need to understand the question.
        Then, I'll analyze the components.
        Finally, I'll provide a comprehensive answer.
        </thinking>
        Based on my analysis, here's the solution.
      CONTENT
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "First, I need to understand"
    assert_includes rendered, "Then, I'll analyze"
    assert_includes rendered, "Finally, I'll provide"
    assert_includes rendered, "Based on my analysis"
  end

  test "thinking dropdown has proper styling classes" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "<thinking>Thinking content</thinking>Main content"
    )

    rendered = render partial: "messages/message", locals: { message: message }

    # Check for thinking-specific styling
    assert_includes rendered, "bg-gray-50"
    assert_includes rendered, "border-l-4"
    assert_includes rendered, "border-gray-300"
    assert_includes rendered, "text-gray-700"

    # Check for dropdown interaction elements
    assert_includes rendered, "transition-transform"
    assert_includes rendered, "duration-200"
  end

  test "renders proper DOM IDs for turbo frame and content" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Test content"
    )

    rendered = render partial: "messages/message", locals: { message: message }

    expected_frame_id = "message_#{message.id}"
    expected_content_id = "content_message_#{message.id}"

    assert_includes rendered, expected_frame_id
    assert_includes rendered, expected_content_id
  end

  test "includes timestamp formatting" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Test message",
      created_at: Time.zone.parse("2024-01-15 14:30:00")
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "02:30 PM"
    assert_includes rendered, "text-xs"
    assert_includes rendered, "text-gray-500"
  end

  test "assistant message has correct avatar and styling" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Assistant response"
    )

    rendered = render partial: "messages/message", locals: { message: message }

    assert_includes rendered, "bg-green-600"
    assert_includes rendered, "AI"
    assert_includes rendered, "rounded-full"
    assert_includes rendered, "bg-white border border-gray-200"
  end
end
