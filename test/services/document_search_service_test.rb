require "test_helper"

class DocumentSearchServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(name: "Test Project", description: "Test Description", user: @user)

    # Create test documents with mock embeddings
    @doc1 = @project.documents.create!(
      title: "Ruby Programming",
      content: "Ruby is a dynamic programming language focused on simplicity and productivity.",
      file_path: "ruby.txt",
      content_type: "text/plain",
      embedding: [ 0.1, 0.2, 0.3, 0.4, 0.5 ]
    )

    @doc2 = @project.documents.create!(
      title: "JavaScript Guide",
      content: "JavaScript is a versatile programming language used for web development.",
      file_path: "js.txt",
      content_type: "text/plain",
      embedding: [ 0.2, 0.3, 0.4, 0.5, 0.6 ]
    )

    @doc3 = @project.documents.create!(
      title: "Python Basics",
      content: "Python is an interpreted programming language known for its readable syntax.",
      file_path: "python.txt",
      content_type: "text/plain",
      embedding: [ 0.3, 0.4, 0.5, 0.6, 0.7 ]
    )
  end

  test "should return relevant documents for search query" do
    # Mock RubyLLM.embed to return a query embedding
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      results = DocumentSearchService.search("programming languages", project_id: @project.id)

      assert_not_empty results
      assert_includes results, "Document: Ruby Programming"
      assert_includes results, "Ruby is a dynamic programming language"
    end
  end

  test "should limit results to specified number" do
    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      results = DocumentSearchService.search("programming", limit: 2, project_id: @project.id)

      # Should contain at most 2 documents
      document_count = results.scan(/Document:/).length
      assert document_count <= 2
    end
  end

  test "should filter results by project_id when provided" do
    # Create another project with documents
    other_project = Project.create!(name: "Other Project", description: "Other Description", user: @user)
    other_doc = other_project.documents.create!(
      title: "Other Document",
      content: "This is from another project.",
      file_path: "other.txt",
      content_type: "text/plain",
      embedding: [ 0.1, 0.2, 0.3, 0.4, 0.5 ]
    )

    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      results = DocumentSearchService.search("document", project_id: @project.id)

      # Should only include documents from the specified project
      assert_not_includes results, "Other Document"
      assert_includes results, "Ruby Programming"
    end
  end

  test "should search all documents when no project_id provided" do
    # Create another project with documents
    other_project = Project.create!(name: "Other Project", description: "Other Description", user: @user)
    other_doc = other_project.documents.create!(
      title: "Other Document",
      content: "This is from another project.",
      file_path: "other.txt",
      content_type: "text/plain",
      embedding: [ 0.1, 0.2, 0.3, 0.4, 0.5 ]
    )

    # Mock RubyLLM.embed and Document.nearest_neighbors to return all docs
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      # Mock the nearest_neighbors method to return all documents
      Document.stub(:all, Document.where(id: [ @doc1.id, @doc2.id, @doc3.id, other_doc.id ])) do
        results = DocumentSearchService.search("document")

        # Should include documents from all projects
        assert_includes results, "Ruby Programming"
      end
    end
  end

  test "should truncate long document content" do
    # Create a document with very long content
    long_content = "A" * 1000
    long_doc = @project.documents.create!(
      title: "Long Document",
      content: long_content,
      file_path: "long.txt",
      content_type: "text/plain",
      embedding: [ 0.1, 0.2, 0.3, 0.4, 0.5 ]
    )

    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      results = DocumentSearchService.search("document", project_id: @project.id)

      # Content should be truncated to 800 characters + "..."
      truncated_content = results[/Content: (.+?)(?:\n|$)/, 1]
      assert truncated_content.length <= 803, "Content should be truncated to ~800 characters"
    end
  end

  test "should return empty string when embedding fails" do
    # Mock RubyLLM.embed to raise an error
    RubyLLM.stub(:embed, ->(_) { raise "API Error" }) do
      results = DocumentSearchService.search("programming", project_id: @project.id)

      assert_equal "", results
    end
  end

  test "should format results with document separators" do
    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      results = DocumentSearchService.search("programming", limit: 2, project_id: @project.id)

      # Should contain document separators
      if results.scan(/Document:/).length > 1
        assert_includes results, "\n\n---\n\n"
      end
    end
  end

  test "should use cosine distance for similarity search" do
    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    # Verify that nearest_neighbors is called with correct parameters
    RubyLLM.stub(:embed, mock_response) do
      Document.any_instance.expects(:nearest_neighbors).with(
        :embedding,
        [ 0.15, 0.25, 0.35, 0.45, 0.55 ],
        distance: "cosine"
      ).returns(Document.where(id: @doc1.id))

      DocumentSearchService.search("programming", project_id: @project.id)
    end
  end

  test "should handle empty search results" do
    # Mock RubyLLM.embed
    mock_response = Struct.new(:vectors).new([ 0.15, 0.25, 0.35, 0.45, 0.55 ])

    RubyLLM.stub(:embed, mock_response) do
      # Mock nearest_neighbors to return empty results
      Document.any_instance.stub(:nearest_neighbors, Document.none) do
        results = DocumentSearchService.search("nonexistent", project_id: @project.id)

        assert_equal "", results
      end
    end
  end
end
