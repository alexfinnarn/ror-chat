# Task: Refactor Ollama Integration Using ActiveRecord Callbacks

## Overview

Refactor the Chat model's Ollama integration to use ActiveRecord callbacks instead of overriding the `complete` method. This will make the code cleaner and more Rails-like by setting up the chat client during object initialization rather than at method call time.

## Background

Currently, the Chat model overrides the `complete` method to handle Ollama models differently from cloud-based models. This approach works but violates the single responsibility principle and makes the method complex. A better approach is to use ActiveRecord callbacks to set up the appropriate chat client during object initialization.

## Current Implementation Issues

1. The `complete` method contains branching logic for different model types
2. Ollama configuration is mixed with business logic
3. The method override approach feels heavy-handed

## Proposed Solution

Use ActiveRecord callbacks (`after_initialize` and `after_find`) to set up the chat client for Ollama models during object lifecycle events, allowing the default `acts_as_chat` behavior to work unchanged.

## Code Changes Required

### File: `app/models/chat.rb`

1. **Remove the `complete` method override entirely**
  - Delete the entire `def complete(&block)...end` method

2. **Add ActiveRecord callbacks**
  - Add `after_initialize :setup_chat_client, if: :ollama_model?`
  - Add `after_find :setup_chat_client, if: :ollama_model?`

3. **Create the `setup_chat_client` private method**
  - Move the Ollama context creation logic from `complete` to this new method
  - Create the `@chat_client` instance variable with proper configuration
  - Load existing conversation history into the client during setup

4. **Keep existing helper methods unchanged**
  - `ollama_model?` method stays as-is
  - `known_cloud_model?` method stays as-is

## Implementation Details

### New Callback Structure
```ruby
after_initialize :setup_chat_client, if: :ollama_model?
after_find :setup_chat_client, if: :ollama_model?
```


### Chat Client Setup
The `setup_chat_client` method should:
- Create an isolated RubyLLM context for Ollama
- Configure the OpenAI-compatible API endpoint (`http://localhost:11434/v1`)
- Set up a dummy API key for Ollama
- Create the chat client with `assume_model_exists: true`
- Load existing conversation history from the database

### Expected Behavior
- Ollama models will automatically have their chat client configured during initialization
- Cloud models will use the default `acts_as_chat` behavior unchanged
- The `complete` method will work for both model types without any overrides
- Conversation history will be preserved and loaded automatically

## Benefits of This Approach

1. **Cleaner separation of concerns**: Configuration happens during initialization, not during method calls
2. **No method overrides**: Leverages the existing `acts_as_chat` functionality
3. **More Rails-like**: Uses standard ActiveRecord callback patterns
4. **Better testability**: Each concern can be tested independently
5. **Easier maintenance**: Adding new model types won't require modifying the `complete` method

## Testing Considerations

After implementing these changes, verify:
- Ollama models still work correctly with streaming responses
- Cloud models continue to work unchanged
- Conversation history is properly maintained
- Error handling remains intact
- The `ChatStreamJob` continues to function properly

## Documentation Updates

Update the `ollama-integration.md` documentation to reflect the new callback-based approach instead of the method override pattern.