namespace :ollama do
  desc "Refresh the list of available Ollama models"
  task refresh: :environment do
    require "net/http"
    require "json"
    require "yaml"

    puts "Fetching Ollama models from http://localhost:11434/api/tags..."

    begin
      uri = URI("http://localhost:11434/api/tags")
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        ollama_models = data["models"] || []

        # Process models into a clean format
        models = ollama_models.map do |model|
          {
            "id" => model["name"],
            "name" => model["name"],
            "display_name" => "#{model['name'].capitalize} (Ollama)",
            "size" => model["size"],
            "modified_at" => model["modified_at"]
          }
        end

        # Prepare config data
        config_data = {
          "last_updated" => Time.current.iso8601,
          "api_endpoint" => "http://localhost:11434",
          "models_count" => models.size,
          "models" => models
        }

        # Write to config file
        config_path = Rails.root.join("config", "ollama_models.yml")
        File.write(config_path, config_data.to_yaml)

        puts "✅ Successfully updated #{models.size} Ollama models in #{config_path}"
        puts "Models found:"
        models.each { |m| puts "  - #{m['id']}" }

      else
        puts "❌ Ollama API returned #{response.code}: #{response.message}"
        puts "Make sure Ollama is running at http://localhost:11434"
        exit 1
      end

    rescue => e
      puts "❌ Failed to connect to Ollama API: #{e.message}"
      puts "Make sure Ollama is running at http://localhost:11434"
      exit 1
    end
  end

  desc "List currently cached Ollama models"
  task list: :environment do
    config_path = Rails.root.join("config", "ollama_models.yml")

    if File.exist?(config_path)
      config = YAML.load_file(config_path)
      models = config["models"] || []

      puts "Cached Ollama models (last updated: #{config['last_updated']}):"
      if models.any?
        models.each { |m| puts "  - #{m['id']}" }
        puts "\nTotal: #{models.size} models"
      else
        puts "  No models cached. Run 'rake ollama:refresh' to fetch models."
      end
    else
      puts "No Ollama models config found. Run 'rake ollama:refresh' to create it."
    end
  end

  desc "Show Ollama configuration"
  task status: :environment do
    config_path = Rails.root.join("config", "ollama_models.yml")

    puts "Ollama configuration:"
    puts "  Config file: #{config_path}"
    puts "  Exists: #{File.exist?(config_path)}"

    if File.exist?(config_path)
      config = YAML.load_file(config_path)
      puts "  Last updated: #{config['last_updated'] || 'Never'}"
      puts "  Models count: #{config['models']&.size || 0}"
      puts "  API endpoint: #{config['api_endpoint'] || 'Not set'}"
    end
  end
end
