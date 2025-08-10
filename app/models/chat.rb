class Chat < ApplicationRecord
  acts_as_chat

  # --- Add your standard Rails model logic below ---
  belongs_to :user
  validates :model_id, presence: true

  broadcasts_to ->(chat) { [chat, "messages"] }
end