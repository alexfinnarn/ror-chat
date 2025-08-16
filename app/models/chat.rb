class Chat < ApplicationRecord
  acts_as_chat

  # --- Add your standard Rails model logic below ---
  belongs_to :user
  validates :model_id, presence: true

  broadcasts_to ->(chat) { [ chat, "messages" ] }

  # Override complete method for Ollama models to use custom client
  def complete(&block)
    if ollama_model?
      # Create Ollama client on-demand
      ollama_context = RubyLLM.context do |config|
        config.openai_api_base = "http://localhost:11434/v1"
        config.openai_api_key = "dummy-key-for-ollama"
      end

      chat_client = ollama_context.chat(
        model: model_id,
        provider: :openai,
        assume_model_exists: true
      )

      # Add existing messages to the conversation
      messages.where.not(content: [ nil, "" ]).order(:created_at).each do |msg|
        chat_client.add_message(role: msg.role, content: msg.content)
      end

      chat_client.complete(&block)
    else
      # Fall back to the default acts_as_chat implementation
      super
    end
  end

  include PgSearch::Model
  pg_search_scope :search_by_title_and_model,
                  against: [ :title, :model_id ],
                  using: {
                    tsearch: { prefix: true }
                  }


  def ollama_model?
    return false if model_id.nil?
    return false if known_cloud_model?

    # First check if model exists in cached Ollama config
    return true if OllamaConfig.model_exists?(model_id)

    # Fallback to pattern detection for models not in cache
    # Ollama models typically use format like "modelname:tag" (e.g., "gemma3:12b", "qwen3:14b")
    model_id.include?(":") && !model_id.include?("/")
  end

  def known_cloud_model?
    # First check if model exists in RubyLLM registry
    return false if model_id.nil?

    begin
      # Try to find the model in the RubyLLM registry
      registry_model = RubyLLM.models.find(model_id)
      return true if registry_model
    rescue
      # If registry lookup fails, fall back to pattern matching
    end

    # Fallback to pattern matching for models not in registry
    cloud_prefixes = %w[
      claude- gpt- text- dall-e gemini- mistral- anthropic. us.anthropic
      openai/ google/ mistralai/ meta-llama/ deepseek/ qwen/
    ]

    cloud_prefixes.any? { |prefix| model_id.downcase.start_with?(prefix.downcase) }
  end
end
