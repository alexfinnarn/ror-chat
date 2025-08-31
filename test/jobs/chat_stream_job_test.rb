require "test_helper"
require "minitest/mock"

class ChatStreamJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)

    # Create a project with instructions and documents
    @project = Project.create!(
      name: "Test Project",
      description: "Test project description",
      instructions: "You are a helpful AI assistant specialized in Ruby programming.",
      user: @user
    )

    # Create documents for the project
    @doc1 = @project.documents.create!(
      title: "Ruby Basics",
      content: "Ruby is a dynamic programming language. It has elegant syntax and is focused on simplicity and productivity.",
      file_path: "ruby_basics.txt",
      content_type: "text/plain",
      embedding: Array.new(768, 0.5)  # 768 dimensions for nomic-embed-text model
    )

    @doc2 = @project.documents.create!(
      title: "Rails Framework",
      content: "Rails is a web application framework written in Ruby. It follows the MVC pattern and emphasizes convention over configuration.",
      file_path: "rails_framework.txt",
      content_type: "text/plain",
      embedding: Array.new(768, 0.6)  # 768 dimensions for nomic-embed-text model
    )

    # Create a chat in the project
    @chat = @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
  end

  test "should register document search tool for project chats with tool support" do
    # Create user and assistant messages
    user_message = @chat.messages.create!(role: "user", content: "What is Ruby?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock chat client to verify tool registration
    mock_client = Minitest::Mock.new
    mock_client.expect(:with_tool, nil) do |tool|
      # Verify WebContentTool is registered
      tool.is_a?(WebContentTool)
    end
    mock_client.expect(:with_tool, nil) do |tool|
      # Verify DocumentSearchTool is registered
      tool.is_a?(DocumentSearchTool)
    end
    mock_client.expect(:add_message, nil, [ Hash ])
    mock_client.expect(:ask, nil) do |prompt, &block|
      # Should be the original user content without automatic enhancement
      assert_equal "What is Ruby?", prompt
      chunk = Struct.new(:content).new("Ruby is a programming language...")
      block.call(chunk) if block
    end

    # Mock supports_tools? to return true
    @chat.stub(:supports_tools?, true) do
      RubyLLM.stub :chat, mock_client do
        ChatStreamJob.perform_now(@chat.id)
      end
    end

    mock_client.verify
  end

  test "should not register document search tool for chats without project" do
    # Create a standalone chat (not in a project)
    standalone_chat = Chat.create!(user: @user, model_id: "gpt-3.5-turbo")
    user_message = standalone_chat.messages.create!(role: "user", content: "Test question")
    assistant_message = standalone_chat.messages.create!(role: "assistant", content: "")

    # Mock chat client to verify only WebContentTool is registered
    mock_client = Minitest::Mock.new
    mock_client.expect(:with_tool, nil) do |tool|
      # Only WebContentTool should be registered, not DocumentSearchTool
      tool.is_a?(WebContentTool)
    end
    mock_client.expect(:add_message, nil, [ Hash ])
    mock_client.expect(:ask, nil) do |prompt, &block|
      assert_equal "Test question", prompt
      chunk = Struct.new(:content).new("Response...")
      block.call(chunk) if block
    end

    # Mock supports_tools? to return true
    standalone_chat.stub(:supports_tools?, true) do
      RubyLLM.stub :chat, mock_client do
        ChatStreamJob.perform_now(standalone_chat.id)
      end
    end

    mock_client.verify
  end

  test "should add project instructions for non-tool models" do
    user_message = @chat.messages.create!(role: "user", content: "What is Python?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    enhanced_prompt_received = nil
    mock_client = Minitest::Mock.new
    mock_client.expect(:add_message, nil, [ Hash ])
    mock_client.expect(:ask, nil) do |prompt, &block|
      enhanced_prompt_received = prompt
      chunk = Struct.new(:content).new("Python is...")
      block.call(chunk) if block
    end

    # Mock supports_tools? to return false for non-tool models
    @chat.stub(:supports_tools?, false) do
      RubyLLM.stub :chat, mock_client do
        ChatStreamJob.perform_now(@chat.id)
      end
    end

    # Should include project instructions as system context for non-tool models
    assert_includes enhanced_prompt_received, "Project Instructions:"
    assert_includes enhanced_prompt_received, "You are a helpful AI assistant specialized in Ruby programming."
    assert_includes enhanced_prompt_received, "User question: What is Python?"

    mock_client.verify
  end

  test "should not enhance prompt for chats without project" do
    # Create a standalone chat (not in a project)
    standalone_chat = Chat.create!(user: @user, model_id: "gpt-3.5-turbo")
    user_message = standalone_chat.messages.create!(role: "user", content: "Hello")
    assistant_message = standalone_chat.messages.create!(role: "assistant", content: "")

    enhanced_prompt_received = nil
    mock_client = Minitest::Mock.new
    mock_client.expect(:add_message, nil, [ Hash ])
    mock_client.expect(:ask, nil) do |prompt, &block|
      enhanced_prompt_received = prompt
      chunk = Struct.new(:content).new("Hello there!")
      block.call(chunk) if block
    end

    RubyLLM.stub :chat, mock_client do
      ChatStreamJob.perform_now(standalone_chat.id)
    end

    # Should just be the original user content without any enhancement
    assert_equal "Hello", enhanced_prompt_received

    mock_client.verify
  end

  test "document search tool can access current chat context" do
    # Create user and assistant messages
    user_message = @chat.messages.create!(role: "user", content: "How do I create a Rails app?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Create a document search tool and verify it can access chat context
    tool = DocumentSearchTool.new

    # Mock the tool's context to simulate being called within a chat
    mock_context = Minitest::Mock.new
    mock_context.expect(:chat, @chat)

    tool.stub(:context, mock_context) do
      # Mock DocumentSearchService
      DocumentSearchService.stub(:search, [ "Mock search results" ]) do
        result = tool.execute(query: "test query")

        assert_includes result, "Found 1 relevant document(s)"
        assert_includes result, "Mock search results"
      end
    end

    mock_context.verify
  end

  test "should handle errors gracefully" do
    user_message = @chat.messages.create!(role: "user", content: "Test question")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock RubyLLM.chat to raise an error
    RubyLLM.stub :chat, ->(_) { raise "API Error" } do
      ChatStreamJob.perform_now(@chat.id)
    end

    # Should update the assistant message with error content
    assistant_message.reload
    assert_includes assistant_message.content, "I apologize, but I encountered an error"
  end
end
