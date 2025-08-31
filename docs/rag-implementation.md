# RAG (Retrieval-Augmented Generation) Implementation

This document describes how the RAG system works in this Rails application to provide contextual 
document search and enhanced AI responses.

## Overview

The RAG system allows AI models to access and reason about project documents by:
1. **Storing documents** with extracted text content and optional manual summaries
2. **Generating embeddings** using local Ollama models for semantic search
3. **Providing document discovery and search tools** for intelligent, on-demand retrieval
4. **Enabling AI models** to first discover available documents, then search for specific content
5. **Manual summary input** allowing users to provide their own document descriptions

## Architecture Components

### Models

#### Document Model (`app/models/document.rb`)
- **Purpose**: Stores document content, vector embeddings, and metadata for semantic search
- **Key Features**:
  - Automatic embedding generation on content changes
  - **Optional manual summary** input during document upload
  - pgvector integration for similarity search
  - Belongs to a project for scoped search
  - **File size and content limits** for performance and reliability

```ruby
class Document < ApplicationRecord
  has_neighbors :embedding
  belongs_to :project
  
  # File size and content limits
  MAX_CONTENT_LENGTH = 200_000 # 200KB of text content (more reasonable for documents)
  MAX_FILE_SIZE = 25.megabytes # 25MB file size (supports larger PDFs)
  SEARCH_RESULT_TRUNCATION = 3_000 # Characters per document in search results
  
  validates :title, :content, presence: true
  validates :content, length: { 
    maximum: MAX_CONTENT_LENGTH,
    message: "Content too long (maximum #{MAX_CONTENT_LENGTH} characters). Consider splitting into smaller documents."
  }
  
  before_save :generate_embedding, if: :content_changed?
  
  # Fields for document metadata
  # summary: text - Optional manual summary provided by user
end
```

**File Size Limits**:
- **Maximum file upload**: 25MB
- **Maximum content length**: 200,000 characters (~200KB of text)
- **Search result truncation**: 3,000 characters per document in RAG context
- **Content handling**: Files exceeding content limit are automatically truncated with user notification
- **Rationale**: Balances document completeness with embedding performance and modern LLM context windows

**Embedding Generation**:
- Uses local Ollama model (`nomic-embed-text:v1.5`) 
- Generates 768-dimensional vectors
- Configured with OpenAI-compatible API endpoint

#### Project Model (`app/models/project.rb`)
- **Purpose**: Groups related documents and chats
- **Key Features**:
  - Has many documents and chats
  - Optional instructions field for context

#### Chat Model (`app/models/chat.rb`)
- **Purpose**: Conversation context with optional project association
- **Key Features**:
  - Belongs to project (optional)
  - Handles both cloud and local Ollama models

### Services

#### DocumentSearchService (`app/services/document_search_service.rb`)
- **Purpose**: Semantic search across project documents
- **How it works**:
  1. Embeds the user query using Ollama
  2. Performs cosine similarity search against stored embeddings
  3. Returns top matching document chunks with titles and content

```ruby
class DocumentSearchService
  def self.search(query, limit: 3, project_id: nil)
    # Generate query embedding
    embedding = ollama_context.embed(query, model: "nomic-embed-text:v1.5").vectors
    
    # Find similar documents
    documents = Document.where(project_id: project_id) if project_id
    results = documents.nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
    
    # Format results
    results.map { |doc| "Document: #{doc.title}\nContent: #{doc.content.truncate(800)}" }
  end
end
```

#### TextExtractionService (`app/services/text_extraction_service.rb`)
- **Purpose**: Extracts text content from uploaded files
- **Supported formats**: PDFs and other document types
- **Integration**: Used by DocumentsController to process uploads

#### DocumentSummaryService (Removed)
- **Previous Purpose**: Generated automatic summaries and suggested titles for documents
- **Current Approach**: Users provide manual summaries during document upload
- **Benefits**: Eliminates LLM processing overhead and gives users control over document descriptions

### Tools

#### DocumentListTool (`app/lib/document_list_tool.rb`)
- **Purpose**: Lists available documents with rich metadata for AI model discovery
- **Key Features**:
  - Shows document titles and filenames
  - Displays manual summaries (when provided), file types, sizes, and upload dates
  - Filtering by content type and title patterns
  - Configurable result limits and summary display
- **Enhanced Workflow**: Enables LLM to discover documents before searching

```ruby
class DocumentListTool < RubyLLM::Tool
  description "Lists available documents in the project with metadata and summaries"
  param :limit, desc: "Maximum number of documents to return (default: 10)"
  param :show_summaries, desc: "Include document summaries in output (default: true)"
  
  def execute(limit: 10, show_summaries: true)
    # Returns rich document metadata with titles and manual summaries
  end
end
```

#### DocumentSearchTool (`app/lib/document_search_tool.rb`)
- **Purpose**: Provides intelligent document search functionality as a tool for AI models
- **Key Features**:
  - On-demand document search when LLM determines it needs context
  - Configurable search parameters (limit, character_limit)
  - Project-scoped search using semantic similarity
  - Works in tandem with DocumentListTool for better targeting

```ruby
class DocumentSearchTool < RubyLLM::Tool
  description "Searches project documents for relevant content using semantic similarity"
  param :query, desc: "Search query to find relevant document content"
  param :limit, desc: "Maximum number of documents to return (default: 3)"
  param :character_limit, desc: "Maximum characters per document (default: 3000)"

  def initialize(project_id: nil)
    super()
    @project_id = project_id
  end

  def execute(query:, limit: 3, character_limit: 3000)
    return "No project associated with this chat" unless @project_id
    
    results = DocumentSearchService.search(query, limit: limit, project_id: @project_id)
    return "No relevant documents found" if results.blank?
    
    "Found relevant document(s):\n\n#{results.truncate(character_limit * limit)}"
  end
end
```

### Jobs

#### ChatStreamJob (`app/jobs/chat_stream_job.rb`)
- **Purpose**: Handles AI chat completion with tool-based RAG integration
- **Enhanced Tool Registration**:

```ruby
# Add tools to the chat client (only for models that support tools)
if chat.supports_tools?
  # Add custom web content tool
  web_tool = WebContentTool.new
  chat_client.with_tool(web_tool)
  
  # Add document tools for project chats (both list and search)
  if chat.project_id.present?
    document_search_tool = DocumentSearchTool.new(project_id: chat.project_id)
    document_list_tool = DocumentListTool.new(project_id: chat.project_id)
    chat_client.with_tool(document_search_tool)
    chat_client.with_tool(document_list_tool)
  end
end

# Add project instructions as system context if present (non-tool models only)
if chat.project_id.present? && !chat.supports_tools?
  project = chat.project
  if project.instructions.present?
    system_prompt = "Project Instructions:\n#{project.instructions}\n\nUser question: #{user_content}"
    user_content = system_prompt
  end
end
```

## Configuration

### Ruby LLM Setup (`config/initializers/ruby_llm.rb`)

```ruby
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  
  # Ollama configuration for both chat and embeddings
  config.ollama_api_base = "http://localhost:11434"
  
  # Configure local embeddings using Ollama
  config.openai_api_base = "http://localhost:11434/v1"
  config.openai_api_key = "dummy-key-for-ollama"
  config.default_embedding_model = "nomic-embed-text:v1.5"
end

# Note: Automatic summary generation has been removed
# Users now provide manual summaries during document upload
```

### Database Schema

#### Documents Table
```ruby
create_table :documents do |t|
  t.text :content              # Extracted text content
  t.string :title              # Document title/filename
  t.string :file_path          # Original file path
  t.string :content_type       # MIME type
  t.vector :embedding, limit: 768  # Vector embeddings (768 dimensions for nomic-embed-text)
  t.references :project, foreign_key: true
  t.text :summary              # Optional manual document summary
  t.timestamps
end

add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
```

**Enhanced Fields**:
- `summary`: Optional manual summary provided by user during upload

**Note**: The embedding dimension was changed from 1536 (OpenAI default) to 768 for the `nomic-embed-text:v1.5` model.

## Workflow

### Enhanced Document Upload and Processing
1. User uploads document via DocumentsController
2. TextExtractionService extracts text content
3. Document saved with `before_save` callbacks:
   - `generate_embedding` creates 768-dimensional embedding vector
   - Manual summary stored if provided by user during upload
4. Vector stored in pgvector column with HNSW index
5. Manual summary stored if provided for enhanced document discovery

### Chat with Tool-Based RAG
1. User sends message in project chat
2. ChatStreamJob processes the request
3. **Enhanced Tool Registration Process**:
   - Check if model supports tools
   - Register WebContentTool for all tool-supporting models
   - Register **both** DocumentListTool and DocumentSearchTool for project chats
   - For non-tool models: Add project instructions as system context
4. **Intelligent Document Discovery and Retrieval**:
   - AI model can first use DocumentListTool to discover available documents
   - Model sees document titles, manual summaries (when provided), and metadata for each document
   - Model makes informed decisions about which documents to search
   - Model then uses DocumentSearchTool for targeted content retrieval
5. AI model responds with document-aware context when needed
6. Response streamed back to user

### Search Algorithm
1. **Intelligent Query Formation**: AI model crafts specific search queries based on user intent
2. **Query Processing**: Search query converted to embedding using same Ollama model
3. **Similarity Search**: Cosine similarity against stored document embeddings
4. **Ranking**: Top N most relevant document chunks returned (configurable limit)
5. **Context Assembly**: Document content truncated based on character_limit and formatted
6. **Selective Usage**: Only executed when AI model determines document context is needed

## Local Model Dependencies

### Required Ollama Models
- **Chat Models**: `gemma3:12b` or other chat models
- **Embedding Model**: `nomic-embed-text:v1.5` (768 dimensions)

### Installation
```bash
# Install embedding model
ollama pull nomic-embed-text:v1.5

# Install chat models (for general chat functionality)
ollama pull gemma3:12b

# Refresh model cache
rake ollama:refresh
```

## Enhanced Benefits

1. **Document Discovery**: AI models can first list available documents before searching, improving targeting
2. **Manual Summaries**: Users can provide meaningful summaries for better LLM understanding
3. **Intelligent RAG**: AI models decide when they need document context instead of automatic injection
4. **Token Efficiency**: Only uses RAG context when actually needed, saving tokens and cost
5. **Better Search Queries**: AI can craft specific search terms based on document discovery
6. **Rich Metadata**: LLMs see document types, sizes, dates, and summaries for informed decisions
7. **Flexible Parameters**: Models can adjust character limits and result counts based on context needs
8. **Multiple Searches**: Models can search multiple times with different queries if needed
9. **Contextual Responses**: AI can answer questions about uploaded documents when relevant
10. **Local Processing**: No external API calls for embeddings or summaries (privacy + cost)
11. **Semantic Search**: Understanding meaning vs. keyword matching
12. **Project Scoping**: Documents only searched within relevant project
13. **Fallback Support**: Non-tool models still get project instructions as system context
14. **User-Controlled Summaries**: Users can optionally provide summaries during upload for better context

## Troubleshooting

### Common Issues

**Embeddings Not Generated**:
- Check Ollama is running: `curl http://localhost:11434/api/tags`
- Verify model installed: `ollama list | grep nomic-embed-text`
- Check Rails logs for embedding errors

**Tool-Based Search Not Working**:
- Verify model supports tools: Check if `chat.supports_tools?` returns true
- Test tools directly: 
  - `DocumentListTool.new(project_id: 1).execute(limit: 5)`
  - `DocumentSearchTool.new(project_id: 1).execute(query: "test")`
- Ensure documents have embeddings: `Document.where(embedding: nil).count`
- Check for missing summaries: `Document.where(summary: nil).count` (summaries are now manual, so this is expected)
- Check tool registration in ChatStreamJob logs

**Summary Management**:
- Summaries are now manually provided during document upload
- No automatic generation occurs - summaries are user-provided or blank

**Dimension Mismatch**:
- Verify embedding column dimension matches model output (768 for nomic-embed-text)
- Run migration if needed to update vector dimensions

**File Upload Issues**:
- **File too large**: Check if file exceeds 25MB limit
- **Content truncated**: Files with >200,000 characters are automatically truncated
- **Processing timeout**: Very large files may timeout during text extraction
- **Memory issues**: Large PDF files may cause memory problems during text extraction
- **Search context**: Each document contributes max 3,000 characters to RAG context

### Debug Commands

```ruby
# Test embedding generation
ollama_context = RubyLLM.context do |config|
  config.openai_api_base = "http://localhost:11434/v1"
  config.openai_api_key = "dummy-key-for-ollama"
end
response = ollama_context.embed("test", model: "nomic-embed-text:v1.5", provider: :openai, assume_model_exists: true)
puts response.vectors.length  # Should be 768

# Check manual summaries
Document.where.not(summary: nil).count
Document.where.not(summary: [nil, '']).pluck(:title, :summary)

# Test document tools
list_tool = DocumentListTool.new(project_id: 1)
list_result = list_tool.execute(limit: 5)
puts list_result

search_tool = DocumentSearchTool.new(project_id: 1)
search_result = search_tool.execute(query: "your query")
puts search_result

# Check document metadata
Document.where.not(embedding: nil).count
Document.where.not(summary: nil).count

# Check document content lengths
Document.select(:id, :title, 'LENGTH(content) as content_length').order(:content_length)

# Note: Summaries are now user-provided, no automatic regeneration
```

## Performance Considerations

- **Index Type**: HNSW index provides fast approximate nearest neighbor search
- **Search Result Truncation**: Each document limited to 3,000 chars in RAG context
- **Search Limit**: Default 3 documents to control context size
- **Local Processing**: Ollama embeddings and summaries avoid API rate limits
- **Manual Summaries**: User-provided summaries eliminate LLM processing overhead
- **File Size Limits**: 
  - 25MB maximum file upload supports larger PDFs while preventing memory issues
  - 200KB maximum content length balances completeness with embedding performance
  - 3,000 character search truncation provides substantial context for modern LLMs
  - Content truncation maintains consistent performance for large documents
- **Embedding Performance**: 768-dimensional vectors balance accuracy and speed

## Implementation Architecture

### Tool-Based vs. Automatic RAG

**Previous Implementation (Automatic)**:
- Documents automatically searched and injected for every project chat message
- Fixed search query based on user input
- Always used tokens for document context, even when not needed
- No intelligence about when context was relevant

**Current Implementation (Tool-Based)**:
- AI model decides when document context is needed
- Model can craft specific, targeted search queries
- Multiple searches possible with refined queries
- Token-efficient: only uses context when actually helpful
- Fallback to system context for non-tool models

### Tool Support by Model Type

- **Tool-Supporting Models** (e.g., GPT-4, Claude 3.5, etc.):
  - Get DocumentSearchTool for project chats
  - Get WebContentTool for web content fetching
  - Intelligent, on-demand context retrieval

- **Non-Tool Models** (e.g., basic Ollama models):
  - Get project instructions as system context
  - Fallback behavior maintains basic functionality

## Future Enhancements

- **Chunking Strategy**: Split large documents into smaller, more focused chunks
- **Hybrid Search**: Combine semantic and keyword search
- **Relevance Scoring**: Show relevance scores in search results
- **Document Metadata**: Include creation dates, authors, and other metadata in search
- **Multiple Embedding Models**: Support different models for different document types
- **Tool Usage Analytics**: Track when and how models use document search
- **Context Window Optimization**: Dynamically adjust character limits based on model capabilities