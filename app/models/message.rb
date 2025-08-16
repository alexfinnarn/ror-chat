class Message < ApplicationRecord
  acts_as_message

  include ActionView::RecordIdentifier

  # Note: Do NOT add "validates :content, presence: true"
  # This would break the assistant message flow described above
  validates :role, presence: true
  validates :chat, presence: true

  broadcasts_to ->(message) { [ message.chat, "messages" ] }

  # Helper to broadcast chunks during streaming
  def broadcast_append_chunk(chunk_content, accumulated_content)
    renderer = ArtifactRenderer.new(accumulated_content)
    formatted_content = renderer.render(dark_mode: false)

    broadcast_update_to [ chat, "messages" ],
                        target: dom_id(self, "content"),
                        html: formatted_content
  end

  # Get artifact renderer for this message
  def artifact_renderer
    return nil unless content.present?
    ArtifactRenderer.new(content)
  end

  # Check if message has any artifacts
  def has_artifacts?
    artifact_renderer&.has_artifacts? || false
  end

  # Check if message contains thinking content
  def has_thinking?
    artifact_renderer&.has_thinking? || false
  end

  # Get all artifacts in this message
  def artifacts
    artifact_renderer&.artifacts || []
  end

  # Get main content (without artifacts)
  def main_content
    artifact_renderer&.remaining_content || content || ""
  end
end
