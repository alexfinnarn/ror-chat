module ChatsHelper
  def chat_models_for_select
    begin
      # Get models from RubyLLM registry
      registry_models = RubyLLM.models.chat_models

      # Define allowed providers from registry
      # allowed_providers = %w[openai anthropic gemini]
      allowed_providers = []

      # Filter registry models to only include allowed providers
      filtered_models = registry_models.select { |model| allowed_providers.include?(model.provider) }

      # Format registry models as [["Display Name (Provider)", "model_id"], ...]
      registry_options = filtered_models.map do |model|
        display_name = "#{model.name} (#{model.provider.to_s.capitalize})"
        [display_name, model.id]
      end

      # Get Ollama models from local API
      ollama_options = fetch_ollama_models

      # Combine registry and Ollama models
      all_options = registry_options + ollama_options
      
      # Sort by provider then by name for better organization
      all_options.sort_by { |display_name, _| display_name }
      
    rescue => e
      Rails.logger.error "Failed to load chat models: #{e.message}"
      
      # Fallback to hard-coded models if everything fails
      [
        ['GPT-4 (OpenAI)', 'gpt-4'],
        ['GPT-3.5 Turbo (OpenAI)', 'gpt-3.5-turbo'],
        ['Claude 3 Sonnet (Anthropic)', 'claude-3-sonnet-20240229'],
        ['Claude 3 Haiku (Anthropic)', 'claude-3-haiku-20240307'],
        ['Gemini Pro (Google)', 'gemini-pro'],
        ['Llama 2 (Ollama)', 'ollama:llama2'],
        ['Mistral (Ollama)', 'ollama:mistral']
      ]
    end
  end

  private

  def fetch_ollama_models
    require 'net/http'
    require 'json'
    
    begin
      uri = URI('http://localhost:11434/api/tags')
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        models = data['models'] || []
        
        # Format Ollama models
        models.map do |model|
          model_name = model['name']
          display_name = "#{model_name.capitalize} (Ollama)"
          [display_name, model_name]
        end
      else
        Rails.logger.warn "Ollama API returned #{response.code}: #{response.message}"
        []
      end
    rescue => e
      Rails.logger.warn "Could not fetch Ollama models: #{e.message}"
      # Return some common Ollama models as fallback
      [
        ['Llama 2 (Ollama)', 'llama2'],
        ['Mistral (Ollama)', 'mistral']
      ]
    end
  end
end
