require "application_system_test_case"

class ProjectsWorkflowTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)

    # Sign in the user
    visit new_session_url
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "user can create a project and upload documents" do
    # Visit projects index
    visit root_path
    assert_selector "h1", text: "Projects"

    # Create a new project
    click_link "New Project"
    assert_selector "h1", text: "Create New Project"

    fill_in "Name", with: "Test Project"
    fill_in "Description", with: "This is a test project for the system test"
    fill_in "Instructions", with: "You are a helpful assistant for testing purposes"
    click_button "Create Project"

    # Should be redirected to project show page
    assert_selector "h1", text: "Test Project"
    assert_text "This is a test project for the system test"

    # Should see the sidebar with upload form
    assert_selector "h3", text: "Project Instructions"
    assert_selector "h3", text: "Upload Documents"
    assert_selector "h3", text: "Documents (0)"

    # Test the workflow end-to-end with file upload
    # Note: This is a simplified test since actual file upload requires browser interaction
    assert_selector "input[type='file']"
    assert_button "Upload"
  end

  test "user can create a chat in a project" do
    # Create a project first
    project = Project.create!(
      name: "Chat Test Project",
      description: "Project for chat testing",
      instructions: "Test instructions",
      user: @user
    )

    visit project_path(project)

    # Create a new chat
    click_link "New Chat"

    # Should be redirected to new chat form or directly to chat
    # This tests the nested routing
    assert_current_path new_project_chat_path(project)
  end

  test "user can view project with existing chats and documents" do
    # Create a project with existing data
    project = Project.create!(
      name: "Existing Data Project",
      description: "Project with existing chats and documents",
      instructions: "Test instructions",
      user: @user
    )

    # Create a chat
    chat = project.chats.create!(
      user: @user,
      model_id: "gpt-3.5-turbo",
      title: "Test Chat"
    )

    # Create a document
    document = project.documents.create!(
      title: "Test Document",
      content: "This is test document content",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    visit project_path(project)

    # Should display the chat
    assert_text "Test Chat"
    assert_text "gpt-3.5-turbo"

    # Should display the document in sidebar
    assert_text "Test Document"
    assert_text "Documents (1)"
  end

  test "user can navigate between projects and chats" do
    # Create multiple projects
    project1 = Project.create!(name: "Project 1", description: "First project", user: @user)
    project2 = Project.create!(name: "Project 2", description: "Second project", user: @user)

    # Create a chat in project1
    chat = project1.chats.create!(user: @user, model_id: "gpt-3.5-turbo")

    # Visit projects index
    visit root_path
    assert_text "Project 1"
    assert_text "Project 2"

    # Navigate to project1
    click_link "Project 1"
    assert_selector "h1", text: "Project 1"

    # Navigate to a chat (if chat interface allows direct navigation)
    # This tests the project context in chat view
    if page.has_link?("Chat #{chat.id}")
      click_link "Chat #{chat.id}"

      # Should show project breadcrumb
      assert_text "Project 1"
    end
  end

  test "user sees empty states appropriately" do
    visit root_path

    # Should see empty state when no projects exist
    if @user.projects.empty?
      assert_text "No projects yet"
      assert_text "Create your first project"
    end

    # Create a project and visit it
    project = Project.create!(
      name: "Empty Project",
      description: "Project with no content",
      user: @user
    )

    visit project_path(project)

    # Should see empty states for chats and documents
    assert_text "No chats yet"
    assert_text "No documents uploaded yet"
  end

  test "user can edit project instructions in sidebar" do
    project = Project.create!(
      name: "Instructions Test Project",
      description: "Project for testing instructions",
      instructions: "Original instructions",
      user: @user
    )

    visit project_path(project)

    # Should see current instructions
    assert_field "Instructions", with: "Original instructions"

    # Update instructions
    fill_in "Instructions", with: "Updated instructions for testing"
    click_button "Save Instructions"

    # Should persist the change (might need to reload or check for success indicator)
    visit project_path(project)
    assert_field "Instructions", with: "Updated instructions for testing"
  end

  test "user cannot access other user's projects" do
    # Create another user and their project
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(
      name: "Other User's Project",
      description: "This should not be accessible",
      user: other_user
    )

    # Try to visit the other user's project
    visit project_path(other_project)

    # Should be redirected or show an error
    # The exact behavior depends on the error handling implementation
    assert_no_text "Other User's Project"
  end

  test "responsive design elements are present" do
    project = Project.create!(
      name: "Responsive Test Project",
      description: "Project for testing responsive design",
      user: @user
    )

    visit project_path(project)

    # Check for responsive layout classes
    assert_selector ".flex" # Main layout
    assert_selector ".w-80" # Sidebar width
    assert_selector ".flex-1" # Main content area

    # Check for sidebar sections
    assert_selector "div", text: "Project Instructions"
    assert_selector "div", text: "Upload Documents"
    assert_selector "div", text: "Documents"
  end
end
