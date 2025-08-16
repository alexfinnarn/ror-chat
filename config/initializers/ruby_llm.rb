RubyLLM.configure do |config|
  # config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]

  # config.default_model = "gpt-4.1-nano"

  # Ollama configuration
  config.ollama_api_base = "http://localhost:11434"
  
  # Configure local embeddings using Ollama
  config.openai_api_base = "http://localhost:11434/v1"
  config.openai_api_key = "dummy-key-for-ollama"
  config.default_embedding_model = "nomic-embed-text:v1.5"
end
