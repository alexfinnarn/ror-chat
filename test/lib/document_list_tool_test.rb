require "test_helper"

class DocumentListToolTest < ActiveSupport::TestCase
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
      summary: "Overview of Ruby programming language",
      embedding: Array.new(768, 0.5)  # 768 dimensions for nomic-embed-text model
    )

    @doc2 = @project.documents.create!(
      title: "Rails Guide",
      content: "Ruby on Rails is a web application framework written in Ruby.",
      file_path: "rails_guide.pdf",
      content_type: "application/pdf",
      summary: "Guide to Rails framework",
      embedding: Array.new(768, 0.3)
    )

    @tool = DocumentListTool.new(project_id: @project.id)
  end

  test "should list documents with metadata" do
    result = @tool.execute(limit: 10)

    assert_includes result, "Available Documents (2)"
    assert_includes result, "Ruby Basics"
    assert_includes result, "Rails Guide"
    assert_includes result, "Type: text/plain"
    assert_includes result, "Type: application/pdf"
    assert_includes result, "Summary: Overview of Ruby programming language"
    assert_includes result, "Summary: Guide to Rails framework"
  end

  test "should respect limit parameter as integer" do
    result = @tool.execute(limit: 1)

    assert_includes result, "Available Documents (1)"
    # Should only show one document
    assert_match(/\A.*Available Documents \(1\).*1\. .*\z/m, result)
  end

  test "should handle boolean show_summaries parameter" do
    result_with_summaries = @tool.execute(show_summaries: true)
    result_without_summaries = @tool.execute(show_summaries: false)

    assert_includes result_with_summaries, "Summary: Overview of Ruby programming language"
    refute_includes result_without_summaries, "Summary: Overview of Ruby programming language"
  end

  test "should handle no project context" do
    tool_without_project = DocumentListTool.new(project_id: nil)
    result = tool_without_project.execute()
    assert_equal "No project associated with this chat", result
  end

  test "should handle no documents" do
    empty_project = Project.create!(
      name: "Empty Project",
      user: @user
    )

    empty_tool = DocumentListTool.new(project_id: empty_project.id)
    result = empty_tool.execute()
    assert_equal "No documents found in this project", result
  end

  test "should filter by content type" do
    result = @tool.execute(content_type_filter: "pdf")

    assert_includes result, "Rails Guide"
    refute_includes result, "Ruby Basics"
  end

  test "should filter by title pattern" do
    result = @tool.execute(title_pattern: "ruby")

    # Should find only Ruby Basics since only it has "Ruby" in title
    assert_includes result, "Ruby Basics"
    refute_includes result, "Rails Guide"
  end
end
