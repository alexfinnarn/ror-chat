class Chat < ApplicationRecord
  acts_as_chat

  # --- Add your standard Rails model logic below ---
  belongs_to :user, optional: true # Example
  validates :model_id, presence: true # Example

  broadcasts_to ->(chat) { [chat, "messages"] }
end