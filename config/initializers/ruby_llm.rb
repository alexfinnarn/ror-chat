RubyLLM.configure do |config|
  # config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]

  # config.default_model = "gpt-4.1-nano"

  # Ollama configuration
  config.ollama_api_base = "http://localhost:11434"
end
