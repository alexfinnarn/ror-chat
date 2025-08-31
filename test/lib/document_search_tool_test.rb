require "test_helper"
require "minitest/mock"

class DocumentSearchToolTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)

    @project = Project.create!(
      name: "Test Project",
      description: "Test project description",
      instructions: "You are a helpful AI assistant.",
      user: @user
    )

    @doc1 = @project.documents.create!(
      title: "Ruby Basics",
      content: "Ruby is a dynamic programming language. It has elegant syntax and is focused on simplicity and productivity.",
      file_path: "ruby_basics.txt",
      content_type: "text/plain",
      embedding: Array.new(768, 0.5)  # 768 dimensions for nomic-embed-text model
    )

    @chat = @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
    @tool = DocumentSearchTool.new(project_id: @project.id)
  end

  test "should execute search with project context" do
    # Mock DocumentSearchService
    expected_results = "Document: Ruby Basics\nContent: Ruby is a dynamic programming language..."
    DocumentSearchService.stub :search, expected_results do
      result = @tool.execute(query: "What is Ruby?")

      assert_includes result, "Found relevant document(s)"
      assert_includes result, "Ruby is a dynamic programming language"
    end
  end

  test "should handle no project context" do
    tool_without_project = DocumentSearchTool.new(project_id: nil)
    result = tool_without_project.execute(query: "test query")
    assert_equal "No project associated with this chat", result
  end

  test "should handle no search results" do
    DocumentSearchService.stub :search, "" do
      result = @tool.execute(query: "nonexistent topic")
      assert_equal "No relevant documents found", result
    end
  end

  test "should respect character limit parameter" do
    long_content = "A" * 5000  # 5000 character string

    DocumentSearchService.stub :search, long_content do
      result = @tool.execute(query: "test", character_limit: 100)

      # Should be truncated to 100 characters plus "..."
      assert result.length < long_content.length
      assert_includes result, "Found relevant document(s)"
    end
  end

  test "should use explicit project_id parameter" do
    # Create another project
    other_project = Project.create!(
      name: "Other Project",
      user: @user
    )

    # Create tool with different project_id
    other_tool = DocumentSearchTool.new(project_id: other_project.id)

    # Mock DocumentSearchService to verify it's called with correct project_id
    search_called_with = nil
    DocumentSearchService.stub :search, ->(query, **options) {
      search_called_with = options
      "Mock results"
    } do
      result = other_tool.execute(query: "test")

      assert_equal other_project.id, search_called_with[:project_id]
      assert_includes result, "Found relevant document(s)"
    end
  end

  test "should handle search service errors gracefully" do
    DocumentSearchService.stub :search, ->(*) { raise "Search error" } do
      result = @tool.execute(query: "test")
      assert_includes result, "Error searching documents: Search error"
    end
  end
end
