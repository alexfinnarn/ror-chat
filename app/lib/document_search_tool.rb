class DocumentSearchTool < RubyLLM::Tool
  description "Searches project documents for relevant content using semantic similarity"
  param :query, desc: "Search query to find relevant document content"
  param :limit, type: "integer", desc: "Maximum number of documents to return (default: 3)"
  param :character_limit, type: "integer", desc: "Maximum characters per document (default: 3000)"

  def initialize(project_id: nil)
    super()
    @project_id = project_id
  end

  def execute(query:, limit: 3, character_limit: 3000)
    return "No project associated with this chat" unless @project_id

    begin
      results = DocumentSearchService.search(query, limit: limit, project_id: @project_id)

      return "No relevant documents found" if results.blank?

      # DocumentSearchService returns a single formatted string, so truncate it if needed
      truncated_results = results.truncate(character_limit * limit)

      "Found relevant document(s):\n\n#{truncated_results}"
    rescue => e
      "Error searching documents: #{e.message}"
    end
  end
end
