require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session = sessions(:one)
    # Set up authentication
    post session_url, params: { email_address: @user.email_address, password: "password" }

    @project = Project.create!(
      name: "Test Project",
      description: "Test project description",
      instructions: "Test instructions",
      user: @user
    )
  end

  test "should get index" do
    get projects_url
    assert_response :success
    assert_select "h1", "Projects"
  end

  test "should show user's projects on index" do
    # Create another user's project that shouldn't be visible
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(name: "Other Project", description: "Other", user: other_user)

    get projects_url
    assert_response :success

    # Should show current user's project
    assert_select "h3 a", text: @project.name
    # Should not show other user's project
    assert_select "h3 a", text: other_project.name, count: 0
  end

  test "should get new" do
    get new_project_url
    assert_response :success
    assert_select "h1", "Create New Project"
  end

  test "should create project with valid params" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          name: "New Project",
          description: "New project description",
          instructions: "New instructions"
        }
      }
    end

    project = Project.last
    assert_equal "New Project", project.name
    assert_equal "New project description", project.description
    assert_equal "New instructions", project.instructions
    assert_equal @user, project.user

    assert_redirected_to project_url(project)
    follow_redirect!
    assert_select "h1", "New Project"
  end

  test "should not create project with invalid params" do
    assert_no_difference("Project.count") do
      post projects_url, params: {
        project: {
          name: "", # Invalid: name can't be blank
          description: "Description"
        }
      }
    end

    assert_response :success
    assert_select "div.bg-red-50" # Error messages container
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
    assert_select "h1", @project.name
    assert_select "p", @project.description
  end

  test "should show project with chats and documents" do
    # Create a chat and document for the project
    chat = @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo", title: "Test Chat")
    document = @project.documents.create!(
      title: "Test Document",
      content: "Test content",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    get project_url(@project)
    assert_response :success

    # Should display chat
    assert_select "a", text: "Test Chat"
    # Should display document
    assert_select "div", text: "Test Document"
  end

  test "should not show other user's project" do
    other_user = User.create!(email_address: "other@example.com", password: "password")
    other_project = Project.create!(name: "Other Project", description: "Other", user: other_user)

    assert_raises(ActiveRecord::RecordNotFound) do
      get project_url(other_project)
    end
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
    assert_select "h1", "Edit Project"
    assert_select "input[value='#{@project.name}']"
  end

  test "should update project with valid params" do
    patch project_url(@project), params: {
      project: {
        name: "Updated Project",
        description: "Updated description",
        instructions: "Updated instructions"
      }
    }

    @project.reload
    assert_equal "Updated Project", @project.name
    assert_equal "Updated description", @project.description
    assert_equal "Updated instructions", @project.instructions

    assert_redirected_to project_url(@project)
  end

  test "should not update project with invalid params" do
    original_name = @project.name

    patch project_url(@project), params: {
      project: {
        name: "" # Invalid: name can't be blank
      }
    }

    @project.reload
    assert_equal original_name, @project.name
    assert_response :success
    assert_select "div.bg-red-50" # Error messages container
  end

  test "should destroy project" do
    assert_difference("Project.count", -1) do
      delete project_url(@project)
    end

    assert_redirected_to projects_url
    follow_redirect!
    assert_select "h1", "Projects"
  end

  test "should destroy project and dependent associations" do
    # Create associated records
    chat = @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
    document = @project.documents.create!(
      title: "Test Document",
      content: "Test content",
      file_path: "test.txt",
      content_type: "text/plain"
    )

    chat_id = chat.id
    document_id = document.id

    delete project_url(@project)

    # Associated records should be destroyed
    assert_not Chat.exists?(chat_id)
    assert_not Document.exists?(document_id)
  end

  test "should require authentication for all actions" do
    # Clear session
    delete session_url

    # Test each action requires authentication
    get projects_url
    assert_redirected_to new_session_url

    get new_project_url
    assert_redirected_to new_session_url

    post projects_url, params: { project: { name: "Test" } }
    assert_redirected_to new_session_url

    get project_url(@project)
    assert_redirected_to new_session_url

    get edit_project_url(@project)
    assert_redirected_to new_session_url

    patch project_url(@project), params: { project: { name: "Updated" } }
    assert_redirected_to new_session_url

    delete project_url(@project)
    assert_redirected_to new_session_url
  end

  test "should handle AJAX update for instructions" do
    patch project_url(@project), params: {
      project: {
        instructions: "Updated instructions via AJAX"
      }
    }, xhr: true

    @project.reload
    assert_equal "Updated instructions via AJAX", @project.instructions
    assert_response :success
  end

  test "should show empty state when no projects exist" do
    @user.projects.destroy_all

    get projects_url
    assert_response :success
    assert_select "h3", "No projects yet"
    assert_select "p", text: /Create your first project/
  end

  test "should display project stats correctly" do
    # Create some chats and documents
    2.times { |i| @project.chats.create!(user: @user, model_id: "gpt-3.5-turbo", title: "Chat #{i}") }
    3.times { |i| @project.documents.create!(title: "Doc #{i}", content: "Content #{i}", file_path: "doc#{i}.txt", content_type: "text/plain") }

    get projects_url
    assert_response :success

    # Should show correct counts
    assert_select "span", text: "2 chats"
    assert_select "span", text: "3 documents"
  end
end
