class OllamaConfig
  CONFIG_PATH = Rails.root.join("config", "ollama_models.yml").freeze

  class << self
    def models
      @models ||= load_models
    end

    def model_ids
      @model_ids ||= models.map { |m| m["id"] }
    end

    def model_exists?(model_id)
      model_ids.include?(model_id)
    end

    def refresh!
      @models = nil
      @model_ids = nil
      load_models
    end

    def models_for_select
      models.map { |m| [ m["display_name"], m["id"] ] }
    end

    def last_updated
      config_data["last_updated"]
    end

    def models_count
      models.size
    end

    def model_supports_tools?(model_id)
      model = models.find { |m| m["id"] == model_id }
      model&.dig("supports_tools") || false
    end

    def tool_capable_models
      models.select { |m| m["supports_tools"] }
    end

    private

    def load_models
      return [] unless File.exist?(CONFIG_PATH)

      config_data["models"] || []
    rescue => e
      Rails.logger.error "Failed to load Ollama models config: #{e.message}"
      []
    end

    def config_data
      @config_data ||= begin
        return {} unless File.exist?(CONFIG_PATH)
        YAML.load_file(CONFIG_PATH) || {}
      end
    end
  end
end
