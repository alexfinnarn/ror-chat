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