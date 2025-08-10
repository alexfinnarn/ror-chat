class AddUserIdAndTitleToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :user_id, :integer
    add_index :chats, :user_id
    add_column :chats, :title, :string
  end
end
