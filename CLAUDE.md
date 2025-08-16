# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8 application building a ChatGPT clone using the Model Context Protocol (MCP). The project aims to create a web-based MCP client with support for OpenAI, Google, Anthropic, and Ollama LLM providers.

### Key Dependencies
- **ruby_llm** gem: Provides LLM connectivity and chat/message helpers
- **Rails 8**: Using Turbo for real-time features and Tailwind CSS for styling
- **Active Storage**: For message file attachments
- **Ollama**: Configured to run locally at http://localhost:11434

## Development Commands

### Setup
```bash
bundle install
rails db:create
rails db:migrate
rails server
```

### Development Server
```bash
# Start all development services
foreman start -f Procfile.dev
# Or individually:
bin/rails server           # Web server
bin/rails tailwindcss:watch # CSS compilation
```

### Testing
```bash
rails test                 # Run all tests
rails test:system         # Run system tests
```

### Linting and Code Quality
```bash
bundle exec rubocop       # Ruby linting (omakase style)
bundle exec brakeman     # Security scanning
```

### Ollama Model Management
```bash
rake ollama:refresh       # Fetch and cache available Ollama models
rake ollama:list         # List currently cached models
rake ollama:status       # Show configuration status
```

## Core Architecture

### Models
- **Chat**: Uses `acts_as_chat` from ruby_llm gem, belongs to User, requires model_id
- **Message**: Uses `acts_as_message` from ruby_llm gem, has file attachments, validates role and chat presence
- **User**: Standard Rails authentication
- **Session**: For user authentication
- **ToolCall**: For MCP tool interactions

### Real-time Features
Both Chat and Message models use Rails 8 broadcasting for real-time updates:
- Chats broadcast to `[chat, "messages"]` stream
- Messages have `broadcast_append_chunk()` method for streaming responses

### Controllers
- **ChatsController**: Manages chat sessions (currently stub implementation)
- **MessagesController**: Handles message CRUD within chat contexts
- Routes follow nested pattern: `/chats/:chat_id/messages`

### LLM Configuration
Configure in `config/initializers/ruby_llm.rb`:
- API keys via environment variables
- Default model selection
- Ollama base URL (currently localhost:11434)

## MCP Implementation Notes

This project follows the Model Context Protocol specification for building MCP clients. Key MCP concepts implemented:
- Resources: For contextual data
- Prompts: For templated interactions  
- Tools: For function calling capabilities

The ruby_llm gem provides the core MCP client functionality through the `acts_as_chat` and `acts_as_message` mixins.

## Artifact System

This project includes a plugin-based artifact system in `lib/artifacts/` for handling special content types in LLM responses:

- **ThinkingArtifact**: Renders `<thinking>` and `<think>` tags as collapsible dropdowns
- **CodeArtifact**: Renders `<code>` tags with syntax highlighting and copy buttons
- **ToolUseArtifact**: Renders `<tool_use>` tags for MCP tool interactions

### Adding New Artifacts

Create new artifact plugins by extending `Artifacts::BaseArtifact`:

```ruby
# lib/artifacts/my_artifact.rb
class MyArtifact < Artifacts::BaseArtifact
  def self.pattern
    /<my_tag>/
  end
  
  def render(dark_mode: false)
    # Custom rendering logic
  end
end

# Auto-register the artifact
Artifacts::ArtifactRegistry.register(MyArtifact)
```

## Development Guidelines

### Code Philosophy
- **No backward compatibility**: This is a modern codebase that evolves without maintaining legacy interfaces
- **Clean and focused**: Write code for current requirements, not hypothetical future needs
- **Plugin architecture**: Prefer extensible plugin systems over hardcoded conditionals
- **Rails conventions**: Follow Rails best practices and omakase philosophy

### Tailwind CSS Guidelines

**Use utility classes directly for:**
- One-off components with unique styling
- Layout classes (flex, grid, containers)
- Component variations (hover states, responsive design)
- Prototyping and initial development

**Use @apply directives for:**
- Repeated style patterns across multiple elements
- Complex component styling that would clutter HTML
- Semantic content styling (like markdown output)
- Base component styles that need consistent application

**Example patterns:**
```css
/* Good: Repeated patterns abstracted with @apply */
.markdown-content h1 { @apply text-lg font-semibold mb-2 mt-4; }
.btn-primary { @apply bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded; }

<!-- Good: Layout and unique styles as utilities -->
<div class="flex items-center justify-between p-4 bg-gray-50">
  <h1 class="text-2xl font-bold text-gray-900">Title</h1>
  <button class="btn-primary">Action</button>
</div>
```

### File Organization
- `app/` - Standard Rails application code
- `lib/` - Custom libraries and plugins (artifacts, utilities)
- `test/` - Comprehensive test coverage including unit, view, and integration tests