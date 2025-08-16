# Projects with RAG Implementation Task

This document outlines the implementation plan for adding a Projects system with RAG (Retrieval Augmented Generation) support to the Rails chat application. The current file upload system has been completely removed and this will implement a more robust document management and retrieval system similar to ChatGPT's "Projects" feature.

## Overview

The goal is to create a Projects system where:
- Users can create projects and upload documents to them
- Chats belong to projects and can access project documents via RAG
- Local models (Ollama) get RAG-enhanced prompts with relevant document content
- Cloud models continue to use native multimodal capabilities when appropriate

## Prerequisites

Add the following gems to your Gemfile:
```ruby
gem 'neighbor'        # Vector similarity search
gem 'pdf-reader'      # PDF text extraction
gem 'docx'           # Word document processing
```

Install pgvector extension in PostgreSQL:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## ✅ Section 1: Remove Current File Upload System - COMPLETED

All file upload related code has been removed from:
- Views: `app/views/messages/_form.html.erb` and `app/views/messages/_message.html.erb`
- Models: `Message` and `Chat` models 
- Controllers: `MessagesController`
- Jobs: `ChatStreamJob`
- JavaScript: `app/javascript/controllers/chat_controller.js`

The codebase is now ready for the Projects/RAG implementation.

## Section 2: Add Basic RAG System

**Note:** The remaining sections (2-5) need to be implemented by the next developer.

### 2.1 Create Documents Migration
```ruby
rails generate migration CreateDocuments content:text title:string file_path:string content_type:string embedding:vector{1536}

# In the migration file, add:
add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
```

### 2.2 Create Document Model
```ruby
# app/models/document.rb
class Document < ApplicationRecord
  has_neighbors :embedding
  
  validates :title, :content, presence: true
  
  before_save :generate_embedding, if: :content_changed?
  
  private
  
  def generate_embedding
    response = RubyLLM.embed(content)
    self.embedding = response.vectors
  rescue => e
    Rails.logger.error "Failed to generate embedding: #{e.message}"
    # Continue without embedding for now
  end
end
```

### 2.3 Create Text Extraction Service
```ruby
# app/services/text_extraction_service.rb
class TextExtractionService
  def self.extract_from_file(file_path)
    case File.extname(file_path).downcase
    when '.pdf'
      extract_from_pdf(file_path)
    when '.txt', '.md'
      File.read(file_path)
    when '.docx'
      extract_from_docx(file_path)
    else
      raise "Unsupported file type: #{File.extname(file_path)}"
    end
  end
  
  private
  
  def self.extract_from_pdf(file_path)
    reader = PDF::Reader.new(file_path)
    reader.pages.map(&:text).join("\n")
  end
  
  def self.extract_from_docx(file_path)
    doc = Docx::Document.open(file_path)
    doc.paragraphs.map(&:text).join("\n")
  end
end
```

### 2.4 Create Document Search Tool
```ruby
# app/services/document_search_service.rb
class DocumentSearchService
  def self.search(query, limit: 3, project_id: nil)
    embedding = RubyLLM.embed(query).vectors
    
    documents = Document.all
    documents = documents.where(project_id: project_id) if project_id
    
    results = documents.nearest_neighbors(
      :embedding,
      embedding,
      distance: "cosine"
    ).limit(limit)
    
    results.map { |doc|
      "Document: #{doc.title}\nContent: #{doc.content.truncate(800)}"
    }.join("\n\n---\n\n")
  rescue => e
    Rails.logger.error "Document search failed: #{e.message}"
    ""
  end
end
```

### 2.5 Update ChatStreamJob for RAG
```ruby
# In app/jobs/chat_stream_job.rb, modify the user message processing:

# Before calling chat_client.ask, add:
if chat.project_id.present?
  relevant_docs = DocumentSearchService.search(user_content, project_id: chat.project_id)
  if relevant_docs.present?
    enhanced_prompt = "Context from project documents:\n#{relevant_docs}\n\nUser question: #{user_content}"
    user_content = enhanced_prompt
  end
end
```

## Section 3: Create Projects Model

### 3.1 Generate Project Model
```ruby
rails generate model Project name:string description:text user:references
```

### 3.2 Update Models with Associations
```ruby
# app/models/project.rb
class Project < ApplicationRecord
  belongs_to :user
  has_many :chats, dependent: :destroy
  has_many :documents, dependent: :destroy
  
  validates :name, presence: true
end

# Update app/models/user.rb
has_many :projects, dependent: :destroy

# Update app/models/chat.rb
belongs_to :project, optional: true

# Update app/models/document.rb
belongs_to :project
```

### 3.3 Create Projects Controller
```ruby
# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  before_action :require_authentication
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  
  def index
    @projects = current_user.projects.order(created_at: :desc)
  end
  
  def show
    @chats = @project.chats.order(created_at: :desc)
    @documents = @project.documents.order(created_at: :desc)
  end
  
  def new
    @project = current_user.projects.build
  end
  
  def create
    @project = current_user.projects.build(project_params)
    if @project.save
      redirect_to @project, notice: 'Project created successfully.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @project.update(project_params)
      redirect_to @project, notice: 'Project updated successfully.'
    else
      render :edit
    end
  end
  
  def destroy
    @project.destroy
    redirect_to projects_path, notice: 'Project deleted successfully.'
  end
  
  private
  
  def set_project
    @project = current_user.projects.find(params[:id])
  end
  
  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

### 3.4 Create Documents Controller
```ruby
# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :require_authentication
  before_action :set_project
  before_action :set_document, only: [:show, :destroy]
  
  def index
    @documents = @project.documents.order(created_at: :desc)
  end
  
  def show
  end
  
  def new
    @document = @project.documents.build
  end
  
  def create
    @document = @project.documents.build
    
    if params[:document][:file].present?
      uploaded_file = params[:document][:file]
      
      # Save uploaded file temporarily
      temp_path = Rails.root.join('tmp', uploaded_file.original_filename)
      File.open(temp_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      begin
        # Extract text content
        content = TextExtractionService.extract_from_file(temp_path)
        
        @document.assign_attributes(
          title: params[:document][:title].presence || uploaded_file.original_filename,
          content: content,
          file_path: uploaded_file.original_filename,
          content_type: uploaded_file.content_type
        )
        
        if @document.save
          redirect_to [@project, @document], notice: 'Document uploaded successfully.'
        else
          render :new
        end
      rescue => e
        @document.errors.add(:file, "Error processing file: #{e.message}")
        render :new
      ensure
        File.unlink(temp_path) if File.exist?(temp_path)
      end
    else
      @document.errors.add(:file, "Please select a file to upload")
      render :new
    end
  end
  
  def destroy
    @document.destroy
    redirect_to project_documents_path(@project), notice: 'Document deleted successfully.'
  end
  
  private
  
  def set_project
    @project = current_user.projects.find(params[:project_id])
  end
  
  def set_document
    @document = @project.documents.find(params[:id])
  end
end
```

### 3.5 Update Routes
```ruby
# config/routes.rb
resources :projects do
  resources :documents, except: [:edit, :update]
  resources :chats, except: [:index]
end

# Update chats routes to be nested under projects
# Remove standalone chats routes if no longer needed
```

## Section 4: Attach RAG System to Projects Model and Views

### 4.1 Update Chat Creation
```ruby
# Update app/controllers/chats_controller.rb
def new
  @project = current_user.projects.find(params[:project_id])
  @chat = @project.chats.build
end

def create
  @project = current_user.projects.find(params[:project_id])
  @chat = @project.chats.build(chat_params)
  @chat.user = current_user
  
  if @chat.save
    redirect_to [@project, @chat]
  else
    render :new
  end
end
```

### 4.2 Create Project Views
```erb
<!-- app/views/projects/index.html.erb -->
<div class="max-w-6xl mx-auto p-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Projects</h1>
    <%= link_to "New Project", new_project_path, class: "btn btn-primary" %>
  </div>
  
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <% @projects.each do |project| %>
      <div class="border rounded-lg p-4 hover:shadow-md transition-shadow">
        <h3 class="font-semibold mb-2"><%= link_to project.name, project %></h3>
        <p class="text-gray-600 text-sm mb-3"><%= project.description %></p>
        <div class="flex justify-between text-xs text-gray-500">
          <span><%= pluralize(project.chats.count, 'chat') %></span>
          <span><%= pluralize(project.documents.count, 'document') %></span>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

```erb
<!-- app/views/projects/show.html.erb -->
<div class="max-w-6xl mx-auto p-6">
  <div class="flex justify-between items-center mb-6">
    <div>
      <h1 class="text-2xl font-bold"><%= @project.name %></h1>
      <p class="text-gray-600"><%= @project.description %></p>
    </div>
    <div class="space-x-2">
      <%= link_to "New Chat", new_project_chat_path(@project), class: "btn btn-primary" %>
      <%= link_to "Upload Document", new_project_document_path(@project), class: "btn btn-secondary" %>
    </div>
  </div>
  
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Chats Section -->
    <div>
      <h2 class="text-lg font-semibold mb-3">Recent Chats</h2>
      <!-- Chat list -->
    </div>
    
    <!-- Documents Section -->
    <div>
      <h2 class="text-lg font-semibold mb-3">Documents</h2>
      <!-- Document list -->
    </div>
  </div>
</div>
```

### 4.3 Update Chat Views
```erb
<!-- Update app/views/chats/show.html.erb to show project context -->
<div class="bg-white border-b border-gray-200 px-6 py-4">
  <div class="flex items-center justify-between">
    <div>
      <div class="flex items-center space-x-2">
        <%= link_to @chat.project.name, @chat.project, class: "text-sm text-blue-600 hover:text-blue-800" %>
        <span class="text-gray-400">/</span>
        <h1 class="text-xl font-semibold text-gray-900">
          <%= @chat.title || "Chat #{@chat.id}" %>
        </h1>
      </div>
      <p class="text-sm text-gray-500">
        Model: <%= @chat.model_id %> • 
        <%= pluralize(@chat.project.documents.count, 'document') %> available
      </p>
    </div>
  </div>
</div>
```

### 4.4 Create Document Upload Views
```erb
<!-- app/views/documents/new.html.erb -->
<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-2xl font-bold mb-6">Upload Document to <%= @project.name %></h1>
  
  <%= form_with model: [@project, @document], multipart: true do |f| %>
    <div class="space-y-4">
      <div>
        <%= f.label :title, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_field :title, class: "mt-1 block w-full rounded-md border-gray-300" %>
      </div>
      
      <div>
        <%= f.label :file, "Choose File", class: "block text-sm font-medium text-gray-700" %>
        <%= f.file_field :file, accept: ".pdf,.txt,.md,.docx", class: "mt-1 block w-full" %>
        <p class="text-xs text-gray-500 mt-1">Supported: PDF, TXT, MD, DOCX</p>
      </div>
      
      <div class="flex space-x-4">
        <%= f.submit "Upload Document", class: "btn btn-primary" %>
        <%= link_to "Cancel", @project, class: "btn btn-secondary" %>
      </div>
    </div>
  <% end %>
</div>
```

## Section 5: Testing and Verification

### 5.1 Test RAG Functionality
1. Create a project
2. Upload a document
3. Create a chat in the project
4. Ask questions about the document content
5. Verify that relevant document content appears in the AI responses

### 5.2 Performance Considerations
- Monitor embedding generation performance
- Consider chunking large documents
- Add background job processing for document uploads
- Implement caching for frequently accessed embeddings

### 5.3 Migration Path
1. Migrate existing chats to a default project
2. Archive or migrate existing message attachments
3. Update any existing references to file uploads

## Notes

- This implementation uses cosine similarity for document retrieval
- Embeddings are generated using the RubyLLM.embed method
- The system gracefully handles embedding failures
- Document content is truncated to prevent token limit issues
- The RAG system works with both local and cloud models