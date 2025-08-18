namespace :ollama do
  desc "Refresh the list of available Ollama models"
  task refresh: :environment do
    require "net/http"
    require "json"
    require "yaml"

    ollama_host = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
    read_timeout = ENV.fetch("READ_TIMEOUT", "30").to_i

    puts "Fetching Ollama models from #{ollama_host}/api/tags..."

    begin
      uri = URI("#{ollama_host}/api/tags")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = read_timeout
      response = http.get(uri.path)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        ollama_models = data["models"] || []

        if ollama_models.empty?
          puts "No local models found"
          config_data = {
            "last_updated" => Time.current.iso8601,
            "api_endpoint" => ollama_host,
            "models_count" => 0,
            "models" => []
          }
          config_path = Rails.root.join("config", "ollama_models.yml")
          File.write(config_path, config_data.to_yaml)
          puts "✅ Updated empty models list in #{config_path}"
          exit 0
        end

        puts "Found #{ollama_models.size} models. Probing for tool support..."

        # Process models into a clean format with tool detection
        models = ollama_models.map.with_index do |model, index|
          model_name = model["name"]
          puts "  [#{index + 1}/#{ollama_models.size}] Probing #{model_name}..."
          
          tool_support = probe_model_for_tools(model_name, ollama_host, read_timeout)
          
          display_name = if tool_support[:supports_tools]
            "#{model_name.capitalize} (Ollama + Tools)"
          else
            "#{model_name.capitalize} (Ollama)"
          end

          {
            "id" => model_name,
            "name" => model_name,
            "display_name" => display_name,
            "supports_tools" => tool_support[:supports_tools],
            "tool_probe_detail" => tool_support[:detail],
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
        puts "\nModels found:"
        models.each do |m|
          tool_indicator = m['supports_tools'] ? ' (Tools: YES)' : ' (Tools: NO)'
          puts "  - #{m['id']}#{tool_indicator}"
        end
        
        tools_count = models.count { |m| m['supports_tools'] }
        puts "\nSummary: #{models.size} total models, #{tools_count} support tools"

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
      
      if config['models']&.any?
        tools_count = config['models'].count { |m| m['supports_tools'] }
        puts "  Tool-capable models: #{tools_count}"
      end
    end
  end

  # Helper method to probe a model for tool support
  def probe_model_for_tools(model_name, ollama_host, read_timeout)
    begin
      uri = URI("#{ollama_host}/api/chat")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = read_timeout
      http.open_timeout = 10

      # Construct the probe request
      probe_data = {
        "model" => model_name,
        "stream" => false,
        "messages" => [
          {
            "role" => "system",
            "content" => "If a tool is available, you should call it."
          },
          {
            "role" => "user", 
            "content" => "What is the weather in Toronto right now? Use the weather tool if needed."
          }
        ],
        "tools" => [
          {
            "type" => "function",
            "function" => {
              "name" => "get_current_weather",
              "description" => "Get current weather for a city",
              "parameters" => {
                "type" => "object",
                "properties" => {
                  "city" => { "type" => "string" }
                },
                "required" => ["city"]
              }
            }
          }
        ]
      }

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = probe_data.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        
        # Check if response contains tool_calls
        message = result["message"]
        if message && message["tool_calls"]
          tool_calls = message["tool_calls"]
          # Normalize to array if single object
          tool_calls = [tool_calls] unless tool_calls.is_a?(Array)
          
          if tool_calls.any?
            function_names = tool_calls.map { |tc| tc.dig("function", "name") }.compact
            detail = "returned tool_calls (#{function_names.join(', ')})"
            return { supports_tools: true, detail: detail }
          end
        end
        
        # No tool calls found
        return { supports_tools: false, detail: "no tool_calls; returned plain text" }
        
      else
        return { supports_tools: false, detail: "error: HTTP #{response.code}: #{response.message}" }
      end

    rescue Net::ReadTimeout, Net::OpenTimeout
      return { supports_tools: false, detail: "error: timeout after #{read_timeout}s" }
    rescue => e
      return { supports_tools: false, detail: "error: #{e.message}" }
    end
  end
end
