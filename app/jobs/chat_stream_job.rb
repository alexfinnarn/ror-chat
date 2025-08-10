class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)

    # Process the latest user message
    chat.complete do |chunk|
      # Get the assistant message record (created before streaming starts)
      assistant_message = chat.messages.last
      if chunk.content && assistant_message
        # Append the chunk content to the message's target div
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
    # Final assistant message is now fully persisted
  end
end
