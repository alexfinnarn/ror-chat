class DocumentListTool < RubyLLM::Tool
  description "Lists available documents in the project with metadata and summaries"
  param :limit, type: "integer", desc: "Maximum number of documents to return (default: 10)"
  param :content_type_filter, desc: "Filter by content type (e.g., 'pdf', 'text')"
  param :title_pattern, desc: "Filter documents by title pattern (case-insensitive)"
  param :show_summaries, type: "boolean", desc: "Include document summaries in output (default: true)"

  def initialize(project_id: nil)
    super()
    @project_id = project_id
  end

  def execute(limit: 10, content_type_filter: nil, title_pattern: nil, show_summaries: true)
    return "No project associated with this chat" unless @project_id

    begin
      documents = Document.where(project_id: @project_id)
      documents = apply_filters(documents, content_type_filter, title_pattern)
      documents = documents.limit(limit).order(created_at: :desc)

      return "No documents found in this project" if documents.empty?

      format_document_list(documents, show_summaries)
    rescue => e
      Rails.logger.error "Document list failed: #{e.message}"
      "Error retrieving document list: #{e.message}"
    end
  end

  private

  def apply_filters(documents, content_type_filter, title_pattern)
    documents = documents.where("content_type ILIKE ?", "%#{content_type_filter}%") if content_type_filter.present?

    if title_pattern.present?
      pattern = "%#{title_pattern}%"
      documents = documents.where("title ILIKE ?", pattern)
    end

    documents
  end

  def format_document_list(documents, show_summaries)
    output = "Available Documents (#{documents.count}):\n\n"

    documents.each_with_index do |doc, index|
      output << format_document_entry(doc, index + 1, show_summaries)
      output << "\n---\n\n" unless index == documents.count - 1
    end

    output.strip
  end

  def format_document_entry(document, index, show_summaries)
    entry = "#{index}. "
    entry << "**#{document.title}**"
    entry << "\n"

    # Add metadata
    entry << "   📄 Type: #{document.content_type || 'Unknown'}\n"
    entry << "   📊 Size: #{format_content_size(document.content.length)}\n"
    entry << "   📅 Uploaded: #{document.created_at.strftime('%b %d, %Y')}\n"

    # Add summary if requested and available
    if show_summaries && document.summary.present?
      entry << "   📝 Summary: #{document.summary}\n"
    end

    entry
  end

  def format_content_size(size)
    if size < 1024
      "#{size} chars"
    elsif size < 1024 * 1024
      "#{(size / 1024.0).round(1)}KB"
    else
      "#{(size / (1024.0 * 1024.0)).round(1)}MB"
    end
  end
end
