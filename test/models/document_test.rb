require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(name: "Test Project", description: "Test Description", user: @user)
  end

  test "should create document with valid attributes" do
    document = @project.documents.build(
      title: "Test Document",
      content: "This is test content for the document.",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    assert document.valid?
    assert document.save
  end

  test "should require title" do
    document = @project.documents.build(
      content: "This is test content for the document.",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    assert_not document.valid?
    assert_includes document.errors[:title], "can't be blank"
  end

  test "should require content" do
    document = @project.documents.build(
      title: "Test Document",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    assert_not document.valid?
    assert_includes document.errors[:content], "can't be blank"
  end

  test "should require project" do
    document = Document.new(
      title: "Test Document",
      content: "This is test content for the document.",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    assert_not document.valid?
    assert_includes document.errors[:project], "must exist"
  end

  test "should generate embedding when content changes" do
    # Mock the RubyLLM.embed method
    mock_response = Struct.new(:vectors).new([ 0.1, 0.2, 0.3 ])
    RubyLLM.stub :embed, mock_response do
      document = @project.documents.create!(
        title: "Test Document",
        content: "This is test content for the document.",
        file_path: "test.txt",
        content_type: "text/plain"
      )

      assert_equal [ 0.1, 0.2, 0.3 ], document.embedding
    end
  end

  test "should handle embedding generation failure gracefully" do
    # Mock RubyLLM.embed to raise an error
    RubyLLM.stub :embed, ->(_) { raise "API Error" } do
      document = @project.documents.build(
        title: "Test Document",
        content: "This is test content for the document.",
        file_path: "test.txt",
        content_type: "text/plain"
      )

      # Should still save the document even if embedding fails
      assert document.save
      assert_nil document.embedding
    end
  end

  test "should not regenerate embedding if content hasn't changed" do
    document = @project.documents.create!(
      title: "Test Document",
      content: "This is test content for the document.",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    # Mock to ensure embed is not called when content doesn't change
    embed_called = false
    RubyLLM.stub :embed, ->(_) { embed_called = true; Struct.new(:vectors).new([ 0.1, 0.2, 0.3 ]) } do
      document.update!(title: "Updated Title")
      assert_not embed_called, "Embedding should not be generated when content doesn't change"
    end
  end

  test "should regenerate embedding when content changes" do
    document = @project.documents.create!(
      title: "Test Document",
      content: "Original content",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    # Mock to track embedding generation
    embed_called = false
    mock_response = Struct.new(:vectors).new([ 0.4, 0.5, 0.6 ])
    RubyLLM.stub :embed, ->(_) { embed_called = true; mock_response } do
      document.update!(content: "Updated content")
      assert embed_called, "Embedding should be generated when content changes"
      assert_equal [ 0.4, 0.5, 0.6 ], document.embedding
    end
  end

  test "should belong to project" do
    document = @project.documents.create!(
      title: "Test Document",
      content: "This is test content for the document.",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    assert_equal @project, document.project
    assert_includes @project.documents, document
  end
end
