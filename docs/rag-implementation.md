# RAG (Retrieval-Augmented Generation) Implementation

This document describes how the RAG system works in this Rails application to provide contextual 
document search and enhanced AI responses.

## Overview

The RAG system allows AI models to access and reason about project documents by:
1. **Storing documents** with extracted text content
2. **Generating embeddings** using local Ollama models for semantic search
3. **Retrieving relevant content** based on user queries
4. **Augmenting AI prompts** with document context and project instructions

## Architecture Components

### Models

#### Document Model (`app/models/document.rb`)
- **Purpose**: Stores document content and vector embeddings for semantic search
- **Key Features**:
  - Automatic embedding generation on content changes
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

### Jobs

#### ChatStreamJob (`app/jobs/chat_stream_job.rb`)
- **Purpose**: Handles AI chat completion with RAG enhancement
- **RAG Integration** (lines 44-64):

```ruby
# Add RAG enhancement if chat belongs to a project
if chat.project_id.present?
  project = chat.project
  enhanced_parts = []

  # Add project instructions if present
  if project.instructions.present?
    enhanced_parts << "Project Instructions:\n#{project.instructions}"
  end

  # Add relevant documents
  relevant_docs = DocumentSearchService.search(user_content, project_id: chat.project_id)
  if relevant_docs.present?
    enhanced_parts << "Context from project documents:\n#{relevant_docs}"
  end

  # Combine everything if we have enhancements
  if enhanced_parts.any?
    enhanced_prompt = "#{enhanced_parts.join("\n\n")}\n\nUser question: #{user_content}"
    user_content = enhanced_prompt
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
  t.timestamps
end

add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
```

**Note**: The embedding dimension was changed from 1536 (OpenAI default) to 768 for the `nomic-embed-text:v1.5` model.

## Workflow

### Document Upload and Processing
1. User uploads document via DocumentsController
2. TextExtractionService extracts text content
3. Document saved with `before_save :generate_embedding` callback
4. Ollama generates 768-dimensional embedding vector
5. Vector stored in pgvector column with HNSW index

### Chat with RAG Enhancement
1. User sends message in project chat
2. ChatStreamJob processes the request
3. **RAG Enhancement Process**:
   - Check if chat belongs to a project
   - Add project instructions (if present)
   - Search for relevant documents using semantic similarity
   - Combine instructions + documents + user query
   - Send enhanced prompt to AI model
4. AI model responds with document-aware context
5. Response streamed back to user

### Search Algorithm
1. **Query Processing**: User query converted to embedding using same Ollama model
2. **Similarity Search**: Cosine similarity against stored document embeddings
3. **Ranking**: Top 3 most relevant document chunks returned
4. **Context Assembly**: Document content truncated to 800 chars and formatted

## Local Model Dependencies

### Required Ollama Models
- **Chat Models**: `gemma3:12b` or other chat models
- **Embedding Model**: `nomic-embed-text:v1.5` (768 dimensions)

### Installation
```bash
# Install embedding model
ollama pull nomic-embed-text:v1.5

# Refresh model cache
rake ollama:refresh
```

## Benefits

1. **Contextual Responses**: AI can answer questions about uploaded documents
2. **Local Processing**: No external API calls for embeddings (privacy + cost)
3. **Semantic Search**: Understanding meaning vs. keyword matching
4. **Project Scoping**: Documents only searched within relevant project
5. **Instructions Support**: Project-level context and guidelines

## Troubleshooting

### Common Issues

**Embeddings Not Generated**:
- Check Ollama is running: `curl http://localhost:11434/api/tags`
- Verify model installed: `ollama list | grep nomic-embed-text`
- Check Rails logs for embedding errors

**Search Not Working**:
- Ensure documents have embeddings: `Document.where(embedding: nil).count`
- Regenerate embeddings: `Document.find_each { |doc| doc.update!(content: doc.content) }`

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

# Test document search
DocumentSearchService.search("your query", project_id: 1)

# Check document embeddings
Document.where.not(embedding: nil).count

# Check document content lengths
Document.select(:id, :title, 'LENGTH(content) as content_length').order(:content_length)

# Find documents that might need chunking
Document.where('LENGTH(content) > ?', Document::MAX_CONTENT_LENGTH / 2)
```

## Performance Considerations

- **Index Type**: HNSW index provides fast approximate nearest neighbor search
- **Search Result Truncation**: Each document limited to 3,000 chars in RAG context
- **Search Limit**: Default 3 documents to control context size
- **Local Processing**: Ollama embeddings avoid API rate limits
- **File Size Limits**: 
  - 25MB maximum file upload supports larger PDFs while preventing memory issues
  - 200KB maximum content length balances completeness with embedding performance
  - 3,000 character search truncation provides substantial context for modern LLMs
  - Content truncation maintains consistent performance for large documents
- **Embedding Performance**: 768-dimensional vectors balance accuracy and speed

## Future Enhancements

- **Chunking Strategy**: Split large documents into smaller, more focused chunks
- **Hybrid Search**: Combine semantic and keyword search
- **Relevance Scoring**: Show relevance scores in search results
- **Document Metadata**: Include creation dates, authors, and other metadata in search
- **Multiple Embedding Models**: Support different models for different document types