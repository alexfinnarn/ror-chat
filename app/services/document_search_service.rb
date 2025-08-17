class DocumentSearchService
  def self.search(query, limit: 3, project_id: nil)
    # Create Ollama embedding context for search queries
    ollama_context = RubyLLM.context do |config|
      config.openai_api_base = "http://localhost:11434/v1"
      config.openai_api_key = "dummy-key-for-ollama"
    end

    embedding = ollama_context.embed(
      query,
      model: "nomic-embed-text:v1.5",
      provider: :openai,
      assume_model_exists: true
    ).vectors

    documents = Document.all
    documents = documents.where(project_id: project_id) if project_id

    results = documents.nearest_neighbors(
      :embedding,
      embedding,
      distance: "cosine"
    ).limit(limit)

    results.map { |doc|
      "Document: #{doc.title}\nContent: #{doc.content.truncate(Document::SEARCH_RESULT_TRUNCATION)}"
    }.join("\n\n---\n\n")
  rescue => e
    Rails.logger.error "Document search failed: #{e.message}"
    ""
  end
end
