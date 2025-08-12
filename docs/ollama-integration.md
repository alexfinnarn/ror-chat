# Ollama Integration

This document outlines how local Ollama models are integrated into the Rails 8 ChatGPT clone 
application using the ruby_llm gem.

## Overview

The application supports both cloud-based AI models (Anthropic Claude, OpenAI GPT) and local 
models running via [Ollama](https://ollama.com). Ollama provides a local server that can run 
various open-source language models like Gemma, Qwen, Llama, and others.

## Prerequisites

### Installing Ollama

1. **Install Ollama**: Download and install from [ollama.com](https://ollama.com)
2. **Start the Ollama service**: The service typically runs on `http://localhost:11434` 
3. **Pull desired models**: 
   ```bash
   ollama pull gemma2:27b
   ollama pull qwen2.5:14b
   ollama pull llama3.1:8b
   ```
4. **Verify installation**: 
   ```bash
   curl http://localhost:11434/api/tags
   ```

### Model Naming Convention

Ollama models use the format `name:tag` (e.g., `gemma2:27b`, `qwen2.5:14b`). This naming pattern 
is how the application detects and routes requests to Ollama.

## Integration Implementation

### 1. Configuration (`config/initializers/ruby_llm.rb`)

```ruby
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  # Set the Ollama API base URL
  config.ollama_api_base = "http://localhost:11434"
end
```

### 2. Model Detection Logic (`app/models/chat.rb`)

The `Chat` model includes logic to detect Ollama models and route them appropriately:

```ruby
def ollama_model?
  # Detect Ollama models by their naming pattern
  # Ollama models typically use format like "modelname:tag" (e.g., "gemma3:12b", "qwen3:14b")
  model_id.include?(":") && !model_id.include?("/") && !known_cloud_model?
end

def known_cloud_model?
  # List of known cloud model prefixes that might contain colons
  cloud_prefixes = %w[
    claude- gpt- text- dall-e gemini- mistral- anthropic. us.anthropic
    openai/ google/ mistralai/ meta-llama/ deepseek/ qwen/
  ]
  
  cloud_prefixes.any? { |prefix| model_id.downcase.start_with?(prefix.downcase) }
end
```

**Key Insight**: The detection relies on Ollama's `name:tag` format while excluding known cloud 
model patterns that might also contain colons.

### 3. OpenAI-Compatible API Routing

The critical breakthrough was discovering that Ollama exposes an OpenAI-compatible API endpoint 
at `/v1`. This allows using the ruby_llm gem's OpenAI provider with Ollama models.

```ruby
def complete(&block)
  if ollama_model?
    # Use OpenAI-compatible API for Ollama models with isolated context
    ollama_context = RubyLLM.context do |config|
      config.openai_api_base = "http://localhost:11434/v1"
      config.openai_api_key = "dummy-key-for-ollama" # Ollama doesn't require auth
    end
    
    chat_client = ollama_context.chat(
      model: model_id,
      provider: :openai,
      assume_model_exists: true
    )
    
    # Set up the conversation with our messages
    messages.where.not(content: [nil, ""]).order(:created_at).each do |msg|
      chat_client.add_message(role: msg.role, content: msg.content)
    end
    
    # Stream the completion
    chat_client.complete(&block)
  else
    # Use the default acts_as_chat behavior for other models
    super(&block)
  end
end
```

### 4. Context Isolation

Using `RubyLLM.context` creates an isolated configuration for Ollama requests without affecting 
the global configuration. This is essential for applications supporting multiple model providers.

## Key Technical Details

### Authentication
- **Ollama**: No API key required. Uses `"dummy-key-for-ollama"` placeholder
- **Cloud Models**: Require valid API keys in environment variables

### API Endpoints
- **Ollama**: `http://localhost:11434/v1` (OpenAI-compatible)
- **Ollama Native**: `http://localhost:11434/api` (Ollama-specific, not used)

### Model Assumption
The `assume_model_exists: true` parameter bypasses model validation, allowing any Ollama model 
name to be used without pre-registration with the ruby_llm gem.

### Conversation History
Messages are loaded from the database and added to the chat context before streaming, 
maintaining conversation continuity across requests.

## Supported Ollama Models

The integration works with any model available via Ollama, including:

- **Gemma** family: `gemma2:9b`, `gemma2:27b`
- **Qwen** family: `qwen2.5:7b`, `qwen2.5:14b`, `qwen2.5:32b`
- **Llama** family: `llama3.1:8b`, `llama3.1:70b`
- **Mistral** family: `mistral:7b`, `mistral-nemo:12b`
- **Custom models**: Any model you've imported or fine-tuned

## Debugging and Troubleshooting

### Common Issues

1. **Ollama Not Running**: 
   ```bash
   # Check if Ollama service is active
   curl http://localhost:11434/api/tags
   ```

2. **Model Not Found**: 
   ```bash
   # List available models
   ollama list
   # Pull missing model
   ollama pull model_name:tag
   ```

3. **Port Conflicts**: Default port is 11434. Check with:
   ```bash
   lsof -i :11434
   ```

### Log Messages
- Look for "Assuming model 'X' exists" in Rails logs - indicates Ollama model detection
- Connection errors suggest Ollama service issues
- Authentication errors shouldn't occur with Ollama (no auth required)

## Performance Considerations

- **Local Processing**: Ollama models run locally, providing privacy and no API costs
- **Hardware Requirements**: Larger models require more RAM and CPU/GPU resources
- **Response Speed**: Varies significantly based on model size and hardware
- **Concurrent Requests**: Ollama handles multiple simultaneous requests

## Security Benefits

- **Data Privacy**: Conversations never leave your local machine
- **No API Limits**: No rate limiting or usage quotas
- **Offline Operation**: Works without internet connectivity
- **Cost**: No per-token charges

This integration provides a seamless way to use local AI models alongside cloud providers, 
giving users choice between privacy/cost (Ollama) and cutting-edge performance (cloud models).
