class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  include ActionView::RecordIdentifier

  # Note: Do NOT add "validates :content, presence: true"
  # This would break the assistant message flow described above
  validates :role, presence: true
  validates :chat, presence: true

  broadcasts_to ->(message) { [ message.chat, "messages" ] }

  # Helper to broadcast chunks during streaming
  def broadcast_append_chunk(chunk_content, accumulated_content)
    # Apply markdown formatting to the accumulated content
    formatted_content = ApplicationController.helpers.markdown_to_html(accumulated_content, dark_mode: false)

    broadcast_update_to [ chat, "messages" ],
                        target: dom_id(self, "content"),
                        html: formatted_content
  end
end
