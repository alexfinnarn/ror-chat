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

  private

  def generate_embedding
    # Create Ollama embedding context similar to chat
    ollama_context = RubyLLM.context do |config|
      config.openai_api_base = "http://localhost:11434/v1"
      config.openai_api_key = "dummy-key-for-ollama"
    end

    response = ollama_context.embed(
      content,
      model: "nomic-embed-text:v1.5",
      provider: :openai,
      assume_model_exists: true
    )
    self.embedding = response.vectors
  rescue => e
    Rails.logger.error "Failed to generate embedding: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Continue without embedding for now
  end
end
