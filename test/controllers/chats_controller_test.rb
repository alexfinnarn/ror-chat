require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password")
    @chat = @user.chats.create!(model_id: "gpt-4", title: "Test Chat")

    # Simulate authentication by creating a session
    @session = @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    # Login by posting to the sessions endpoint to set the proper cookie
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "should get index" do
    get chats_url
    assert_response :success
    assert_select "h1", "Your chat history"
  end

  test "should get new" do
    get new_chat_url
    assert_response :success
    assert_select "h1", "Create New Chat"
  end

  test "should create chat" do
    assert_difference("Chat.count") do
      post chats_url, params: { chat: { model_id: "gpt-3.5-turbo", title: "New Test Chat" } }
    end

    assert_redirected_to chat_url(Chat.last)
  end

  test "should show chat" do
    get chat_url(@chat)
    assert_response :success
  end
end
