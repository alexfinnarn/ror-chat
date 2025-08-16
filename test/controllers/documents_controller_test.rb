require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session = sessions(:one)
    # Set up authentication
    post session_url, params: { email_address: @user.email_address, password: "password" }

    @project = Project.create!(
      name: "Test Project",
      description: "Test project description",
      user: @user
    )

    @document = @project.documents.create!(
      title: "Test Document",
      content: "Test document content",
      file_path: "test.txt",
      content_type: "text/plain"
    )
  end

  test "should get index" do
    get project_documents_url(@project)
    assert_response :success
  end

  test "should show project's documents on index" do
    # Create another project's document that shouldn't be visible
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(name: "Other Project", description: "Other", user: other_user)
    other_document = other_project.documents.create!(
      title: "Other Document",
      content: "Other content",
      file_path: "other.txt",
      content_type: "text/plain"
    )

    get project_documents_url(@project)
    assert_response :success

    # Should show current project's document
    assert_includes response.body, @document.title
    # Should not show other project's document
    assert_not_includes response.body, other_document.title
  end

  test "should get new" do
    get new_project_document_url(@project)
    assert_response :success
  end

  test "should show document" do
    get project_document_url(@project, @document)
    assert_response :success
  end

  test "should create document with file upload" do
    # Create a temporary test file
    file_content = "This is test file content for document upload."
    temp_file = Tempfile.new([ "test", ".txt" ])
    temp_file.write(file_content)
    temp_file.rewind

    # Mock the file upload
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, "text/plain", original_filename: "uploaded_test.txt")

    # Mock TextExtractionService
    TextExtractionService.stub(:extract_from_file, file_content) do
      assert_difference("Document.count") do
        post project_documents_url(@project), params: {
          file: uploaded_file
        }
      end
    end

    document = Document.last
    assert_equal "uploaded_test.txt", document.title
    assert_equal file_content, document.content
    assert_equal "uploaded_test.txt", document.file_path
    assert_equal "text/plain", document.content_type
    assert_equal @project, document.project

    assert_redirected_to project_url(@project)

    temp_file.close
    temp_file.unlink
  end

  test "should create document with AJAX request" do
    file_content = "AJAX test content"
    temp_file = Tempfile.new([ "ajax_test", ".txt" ])
    temp_file.write(file_content)
    temp_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, "text/plain", original_filename: "ajax_test.txt")

    TextExtractionService.stub(:extract_from_file, file_content) do
      assert_difference("Document.count") do
        post project_documents_url(@project), params: {
          file: uploaded_file
        }, xhr: true
      end
    end

    assert_response :success
    assert_equal "text/javascript", response.content_type.split(";").first

    temp_file.close
    temp_file.unlink
  end

  test "should not create document without file" do
    assert_no_difference("Document.count") do
      post project_documents_url(@project), params: {}
    end

    assert_response :success
  end

  test "should not create document with AJAX when no file provided" do
    post project_documents_url(@project), params: {}, xhr: true

    assert_response :success
    assert_equal "text/javascript", response.content_type.split(";").first
  end

  test "should handle file processing errors gracefully" do
    temp_file = Tempfile.new([ "error_test", ".txt" ])
    temp_file.write("test content")
    temp_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, "text/plain", original_filename: "error_test.txt")

    # Mock TextExtractionService to raise an error
    TextExtractionService.stub(:extract_from_file, ->(_) { raise "File processing error" }) do
      assert_no_difference("Document.count") do
        post project_documents_url(@project), params: {
          file: uploaded_file
        }
      end
    end

    assert_response :success

    temp_file.close
    temp_file.unlink
  end

  test "should handle file processing errors with AJAX" do
    temp_file = Tempfile.new([ "ajax_error_test", ".txt" ])
    temp_file.write("test content")
    temp_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, "text/plain", original_filename: "ajax_error_test.txt")

    TextExtractionService.stub(:extract_from_file, ->(_) { raise "AJAX file processing error" }) do
      post project_documents_url(@project), params: {
        file: uploaded_file
      }, xhr: true
    end

    assert_response :success
    assert_equal "text/javascript", response.content_type.split(";").first

    temp_file.close
    temp_file.unlink
  end

  test "should destroy document" do
    assert_difference("Document.count", -1) do
      delete project_document_url(@project, @document)
    end

    assert_redirected_to project_url(@project)
  end

  test "should destroy document with AJAX" do
    assert_difference("Document.count", -1) do
      delete project_document_url(@project, @document), xhr: true
    end

    assert_response :success
    assert_equal "text/javascript", response.content_type.split(";").first
  end

  test "should not access other user's project documents" do
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(name: "Other Project", description: "Other", user: other_user)

    assert_raises(ActiveRecord::RecordNotFound) do
      get project_documents_url(other_project)
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      get new_project_document_url(other_project)
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      post project_documents_url(other_project), params: { file: "test" }
    end
  end

  test "should not access other project's documents" do
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(name: "Other Project", description: "Other", user: other_user)
    other_document = other_project.documents.create!(
      title: "Other Document",
      content: "Other content",
      file_path: "other.txt",
      content_type: "text/plain"
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      get project_document_url(@project, other_document)
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      delete project_document_url(@project, other_document)
    end
  end

  test "should require authentication for all actions" do
    # Clear session
    delete session_url

    # Test each action requires authentication
    get project_documents_url(@project)
    assert_redirected_to new_session_url

    get new_project_document_url(@project)
    assert_redirected_to new_session_url

    post project_documents_url(@project), params: { file: "test" }
    assert_redirected_to new_session_url

    get project_document_url(@project, @document)
    assert_redirected_to new_session_url

    delete project_document_url(@project, @document)
    assert_redirected_to new_session_url
  end

  test "should handle different file types" do
    file_types = [
      { ext: ".txt", type: "text/plain", content: "Plain text content" },
      { ext: ".md", type: "text/markdown", content: "# Markdown content" },
      { ext: ".pdf", type: "application/pdf", content: "PDF content" },
      { ext: ".docx", type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", content: "DOCX content" }
    ]

    file_types.each do |file_type|
      temp_file = Tempfile.new([ "test", file_type[:ext] ])
      temp_file.write("dummy file content")
      temp_file.rewind

      uploaded_file = Rack::Test::UploadedFile.new(
        temp_file.path,
        file_type[:type],
        original_filename: "test#{file_type[:ext]}"
      )

      TextExtractionService.stub(:extract_from_file, file_type[:content]) do
        assert_difference("Document.count") do
          post project_documents_url(@project), params: {
            file: uploaded_file
          }
        end
      end

      document = Document.last
      assert_equal file_type[:content], document.content
      assert_equal file_type[:type], document.content_type

      temp_file.close
      temp_file.unlink
    end
  end

  test "should clean up temporary files after processing" do
    temp_file = Tempfile.new([ "cleanup_test", ".txt" ])
    temp_file.write("test content")
    temp_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, "text/plain", original_filename: "cleanup_test.txt")

    # Track temp file creation and cleanup
    temp_files_created = []
    original_join = Rails.root.method(:join)

    Rails.root.stub(:join, ->(path, filename) {
      if path == "tmp"
        temp_path = original_join.call(path, filename)
        temp_files_created << temp_path.to_s
        temp_path
      else
        original_join.call(path, filename)
      end
    }) do
      TextExtractionService.stub(:extract_from_file, "extracted content") do
        post project_documents_url(@project), params: {
          file: uploaded_file
        }
      end
    end

    # Temporary files should be cleaned up
    temp_files_created.each do |temp_file_path|
      assert_not File.exist?(temp_file_path), "Temporary file #{temp_file_path} should be cleaned up"
    end

    temp_file.close
    temp_file.unlink
  end
end
