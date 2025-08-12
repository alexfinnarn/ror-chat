class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    assistant_message = chat.messages.where(role: "assistant").last

    return unless assistant_message

    begin
      full_response = ""

      # Process the chat completion with streaming
      chat.complete do |chunk|
        if chunk.content && assistant_message
          # Accumulate the response content
          full_response += chunk.content
          # Broadcast the formatted accumulated content
          assistant_message.broadcast_append_chunk(chunk.content, full_response)
        end
      end

      # Update the assistant message with the full response
      assistant_message.update!(content: full_response) if full_response.present?

    rescue => error
      Rails.logger.error "ChatStreamJob failed for chat #{chat_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")

      # Update the assistant message with error information
      error_message = "I apologize, but I encountered an error while processing your request. Please try again."
      assistant_message.update!(content: error_message)

      # Broadcast the error message to replace "Thinking..."
      assistant_message.broadcast_replace_to(
        [ chat, "messages" ],
        partial: "messages/message",
        locals: { message: assistant_message }
      )
    end
  end
end
