# RoR Chat

The purpose of this repo is to build a ChatGPT clone using Rails. ChatGPT clones fall loosely in 
the category of "MCP Clients" so the Model Context Protocol will be referenced a lot.

## Overview

It is a good idea to read the MCP documentation around clients:

- Concepts -  https://modelcontextprotocol.io/docs/learn/client-concepts
- Build a client tutorial - https://modelcontextprotocol.io/quickstart/client
- Latest MCP spec - https://modelcontextprotocol.io/specification/2025-06-18

### Competition

We might as well point out the competition of open soure MCP clients that this project will look 
towards for examples of how to provide MCP client implementations. 

A couple places on the web do a great job listing MCP clients:

- https://github.com/punkpeye/awesome-mcp-clients - does a great job 
listing out open source MCP clients with metadata about them.
- https://modelcontextprotocol.io/clients - Lists clients in a table according to how much of 
  the MCP client spec they implement.

### Initial Goals

The initial goals of this project will remain simple and draw a contrast to other open source 
MCP clients that propose to do everything for everyone.

1. Only provide a web interface for the client. No need to add complexity to create builds for 
   OSes. Everyone can use the command line, if they want.
2. Limit providers to avoid adding confusion and complexity. We will start with OpenAI, 
   Google, Anthropic, and Ollama support. 
3. Stick to Resources, prompts, and tools from the MCP spec for clients. Once those features are 
   working well, we can add more.

### Ruby LLM Dependencies

We will rely on two gems to provide LLM and agentic functionality:

- [Ruby LLM](https://github.com/crmne/ruby_llm) - Provides a way to connect to LLMs as well as 
  helpers for chats, messages, and tools.
- [Active Agent](https://github.com/activeagents/activeagent) - Provides a way to create agents 
  using the same MVC pattern and concepts as Rails.

## Development

This is a typical Ruby on Rails project. To set it up locally, run:

```bash
bundle install
rails db:create
rails db:migrate
rails server
```

### Testing

Testing needs to be set up using Rails best practices for testing.
