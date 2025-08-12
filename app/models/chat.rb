class Chat < ApplicationRecord
  acts_as_chat

  # --- Add your standard Rails model logic below ---
  belongs_to :user
  validates :model_id, presence: true

  broadcasts_to ->(chat) { [ chat, "messages" ] }

  # Set up chat client for Ollama models during initialization
  after_initialize :setup_chat_client, if: :ollama_model?
  after_find :setup_chat_client, if: :ollama_model?

  private

  def setup_chat_client
    # Use OpenAI-compatible API for Ollama models with isolated context
    ollama_context = RubyLLM.context do |config|
      config.openai_api_base = "http://localhost:11434/v1"
      config.openai_api_key = "dummy-key-for-ollama" # Ollama doesn't require auth
    end

    @chat_client = ollama_context.chat(
      model: model_id,
      provider: :openai,
      assume_model_exists: true
    )

    # Set up the conversation with existing messages
    messages.where.not(content: [ nil, "" ]).order(:created_at).each do |msg|
      @chat_client.add_message(role: msg.role, content: msg.content)
    end
  end

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
