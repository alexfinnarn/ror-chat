class AddForeignKeyForUserIdToChats < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :chats, :users
  end
end
