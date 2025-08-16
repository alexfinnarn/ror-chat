require "test_helper"

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
      embedding: [ 0.1, 0.2, 0.3, 0.4, 0.5 ]
    )

    @doc2 = @project.documents.create!(
      title: "Rails Framework",
      content: "Rails is a web application framework written in Ruby. It follows the MVC pattern and emphasizes convention over configuration.",
      file_path: "rails_framework.txt",
      content_type: "text/plain",
      embedding: [ 0.2, 0.3, 0.4, 0.5, 0.6 ]
    )

    # Create a chat in the project
    @chat = @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
  end

  test "should enhance prompt with project instructions and relevant documents" do
    # Create user and assistant messages
    user_message = @chat.messages.create!(role: "user", content: "What is Ruby?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock DocumentSearchService to return relevant documents
    relevant_docs = "Document: Ruby Basics\nContent: Ruby is a dynamic programming language. It has elegant syntax and is focused on simplicity and productivity."
    DocumentSearchService.stub(:search, relevant_docs) do
      # Mock RubyLLM chat client
      enhanced_prompt_received = nil
      mock_client = Minitest::Mock.new
      mock_client.expect(:add_message, nil, [ Hash ])
      mock_client.expect(:ask, nil) do |prompt, &block|
        enhanced_prompt_received = prompt
        # Simulate streaming response
        chunk = Struct.new(:content).new("Ruby is a programming language...")
        yield chunk if block_given?
      end

      RubyLLM.stub(:chat, mock_client) do
        ChatStreamJob.perform_now(@chat.id)
      end

      # Verify the prompt was enhanced with instructions and documents
      assert_not_nil enhanced_prompt_received
      assert_includes enhanced_prompt_received, "Project Instructions:"
      assert_includes enhanced_prompt_received, "You are a helpful AI assistant specialized in Ruby programming."
      assert_includes enhanced_prompt_received, "Context from project documents:"
      assert_includes enhanced_prompt_received, "Ruby is a dynamic programming language"
      assert_includes enhanced_prompt_received, "User question: What is Ruby?"

      mock_client.verify
    end
  end

  test "should work without project instructions when not provided" do
    # Create a project without instructions
    project_without_instructions = Project.create!(
      name: "No Instructions Project",
      description: "Project without instructions",
      user: @user
    )

    chat = project_without_instructions.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
    user_message = chat.messages.create!(role: "user", content: "Test question")
    assistant_message = chat.messages.create!(role: "assistant", content: "")

    # Mock DocumentSearchService to return no documents
    DocumentSearchService.stub(:search, "") do
      enhanced_prompt_received = nil
      mock_client = Minitest::Mock.new
      mock_client.expect(:add_message, nil, [ Hash ])
      mock_client.expect(:ask, nil) do |prompt, &block|
        enhanced_prompt_received = prompt
        chunk = Struct.new(:content).new("Response...")
        yield chunk if block_given?
      end

      RubyLLM.stub(:chat, mock_client) do
        ChatStreamJob.perform_now(chat.id)
      end

      # Should just be the original user content without enhancement
      assert_equal "Test question", enhanced_prompt_received

      mock_client.verify
    end
  end

  test "should work without relevant documents when none found" do
    user_message = @chat.messages.create!(role: "user", content: "What is Python?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock DocumentSearchService to return no relevant documents
    DocumentSearchService.stub(:search, "") do
      enhanced_prompt_received = nil
      mock_client = Minitest::Mock.new
      mock_client.expect(:add_message, nil, [ Hash ])
      mock_client.expect(:ask, nil) do |prompt, &block|
        enhanced_prompt_received = prompt
        chunk = Struct.new(:content).new("Python is...")
        yield chunk if block_given?
      end

      RubyLLM.stub(:chat, mock_client) do
        ChatStreamJob.perform_now(@chat.id)
      end

      # Should only include project instructions, not document context
      assert_includes enhanced_prompt_received, "Project Instructions:"
      assert_includes enhanced_prompt_received, "You are a helpful AI assistant specialized in Ruby programming."
      assert_not_includes enhanced_prompt_received, "Context from project documents:"
      assert_includes enhanced_prompt_received, "User question: What is Python?"

      mock_client.verify
    end
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
      yield chunk if block_given?
    end

    RubyLLM.stub(:chat, mock_client) do
      ChatStreamJob.perform_now(standalone_chat.id)
    end

    # Should just be the original user content without any enhancement
    assert_equal "Hello", enhanced_prompt_received

    mock_client.verify
  end

  test "should call DocumentSearchService with correct parameters" do
    user_message = @chat.messages.create!(role: "user", content: "How do I create a Rails app?")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock DocumentSearchService to verify it's called correctly
    search_called_with = nil
    DocumentSearchService.stub(:search, ->(query, **options) {
      search_called_with = { query: query, options: options }
      "Mock document results"
    }) do
      mock_client = Minitest::Mock.new
      mock_client.expect(:add_message, nil, [ Hash ])
      mock_client.expect(:ask, nil) do |prompt, &block|
        chunk = Struct.new(:content).new("To create a Rails app...")
        yield chunk if block_given?
      end

      RubyLLM.stub(:chat, mock_client) do
        ChatStreamJob.perform_now(@chat.id)
      end

      mock_client.verify
    end

    # Verify DocumentSearchService was called with correct parameters
    assert_not_nil search_called_with
    assert_equal "How do I create a Rails app?", search_called_with[:query]
    assert_equal @project.id, search_called_with[:options][:project_id]
  end

  test "should handle errors gracefully" do
    user_message = @chat.messages.create!(role: "user", content: "Test question")
    assistant_message = @chat.messages.create!(role: "assistant", content: "")

    # Mock RubyLLM.chat to raise an error
    RubyLLM.stub(:chat, ->(_) { raise "API Error" }) do
      ChatStreamJob.perform_now(@chat.id)
    end

    # Should update the assistant message with error content
    assistant_message.reload
    assert_includes assistant_message.content, "I apologize, but I encountered an error"
  end
end
