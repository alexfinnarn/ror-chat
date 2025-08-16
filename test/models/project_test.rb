require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "should create project with valid attributes" do
    project = @user.projects.build(
      name: "Test Project",
      description: "Test project description",
      instructions: "Test instructions for the project"
    )

    assert project.valid?
    assert project.save
  end

  test "should require name" do
    project = @user.projects.build(
      description: "Test project description"
    )

    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "should require user" do
    project = Project.new(
      name: "Test Project",
      description: "Test project description"
    )

    assert_not project.valid?
    assert_includes project.errors[:user], "must exist"
  end

  test "should have many chats" do
    project = @user.projects.create!(name: "Test Project", description: "Test Description")

    # Create chats for the project
    chat1 = project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")
    chat2 = project.chats.create!(user: @user, model_id: "gpt-4")

    assert_includes project.chats, chat1
    assert_includes project.chats, chat2
    assert_equal 2, project.chats.count
  end

  test "should have many documents" do
    project = @user.projects.create!(name: "Test Project", description: "Test Description")

    # Create documents for the project
    doc1 = project.documents.create!(title: "Doc 1", content: "Content 1", file_path: "doc1.txt", content_type: "text/plain")
    doc2 = project.documents.create!(title: "Doc 2", content: "Content 2", file_path: "doc2.txt", content_type: "text/plain")

    assert_includes project.documents, doc1
    assert_includes project.documents, doc2
    assert_equal 2, project.documents.count
  end

  test "should destroy dependent chats when project is destroyed" do
    project = @user.projects.create!(name: "Test Project", description: "Test Description")
    chat = project.chats.create!(user: @user, model_id: "gpt-3.5-turbo")

    chat_id = chat.id
    project.destroy

    assert_not Chat.exists?(chat_id)
  end

  test "should destroy dependent documents when project is destroyed" do
    project = @user.projects.create!(name: "Test Project", description: "Test Description")
    document = project.documents.create!(title: "Test Doc", content: "Test Content", file_path: "test.txt", content_type: "text/plain")

    document_id = document.id
    project.destroy

    assert_not Document.exists?(document_id)
  end

  test "instructions can be optional" do
    project = @user.projects.build(
      name: "Test Project",
      description: "Test project description"
    )

    assert project.valid?
    assert_nil project.instructions
  end

  test "should belong to user" do
    project = @user.projects.create!(name: "Test Project", description: "Test Description")

    assert_equal @user, project.user
    assert_includes @user.projects, project
  end
end
