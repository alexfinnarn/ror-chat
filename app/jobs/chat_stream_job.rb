require_relative "../lib/web_content_tool"

class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    user_message = chat.messages.where(role: "user").last
    assistant_message = chat.messages.where(role: "assistant").last

    return unless assistant_message && user_message

    begin
      full_response = ""

      # Get the user's message content
      user_content = user_message.content

      # Create chat client (handle Ollama vs cloud models)
      chat_client = if chat.ollama_model?
        # Create Ollama client on-demand
        ollama_context = RubyLLM.context do |config|
          config.openai_api_base = "http://localhost:11434/v1"
          config.openai_api_key = "dummy-key-for-ollama"
        end

        ollama_context.chat(
          model: chat.model_id,
          provider: :openai,
          assume_model_exists: true
        )
      else
        RubyLLM.chat(model: chat.model_id)
      end

      # Add tools to the chat client (only for models that support tools)
      if chat.supports_tools?
        # Add custom web content tool
        web_tool = WebContentTool.new
        chat_client.with_tool(web_tool)
      end

      # Add previous messages to the conversation (excluding the current user message and assistant message)
      previous_messages = chat.messages.where.not(content: [ nil, "" ])
                             .where.not(id: [ user_message.id, assistant_message.id ])
                             .order(:created_at)

      previous_messages.each do |msg|
        chat_client.add_message(role: msg.role, content: msg.content)
      end

      # Add RAG enhancement if chat belongs to a project
      if chat.project_id.present?
        project = chat.project
        enhanced_parts = []

        # Add project instructions if present
        if project.instructions.present?
          enhanced_parts << "Project Instructions:\n#{project.instructions}"
        end

        # Add relevant documents
        relevant_docs = DocumentSearchService.search(user_content, project_id: chat.project_id)
        if relevant_docs.present?
          enhanced_parts << "Context from project documents:\n#{relevant_docs}"
        end

        # Combine everything if we have enhancements
        if enhanced_parts.any?
          enhanced_prompt = "#{enhanced_parts.join("\n\n")}\n\nUser question: #{user_content}"
          user_content = enhanced_prompt
        end
      end

      # Process the chat completion with streaming
      chat_client.ask(user_content) do |chunk|
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
