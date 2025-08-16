class Message < ApplicationRecord
  acts_as_message

  has_many_attached :attachments
  include ActionView::RecordIdentifier

  # Note: Do NOT add "validates :content, presence: true"
  # This would break the assistant message flow described above
  validates :role, presence: true
  validates :chat, presence: true

  broadcasts_to ->(message) { [ message.chat, "messages" ] }

  # Helper to broadcast chunks during streaming
  def broadcast_append_chunk(chunk_content, accumulated_content)
    formatted_content = build_streaming_content(accumulated_content)

    broadcast_update_to [ chat, "messages" ],
                        target: dom_id(self, "content"),
                        html: formatted_content
  end

  # Check if message contains thinking content
  def has_thinking_content?
    return false unless content.present?
    content.match?(/<thinking>.*?<\/thinking>|<think>.*?<\/think>/m)
  end

  # Extract thinking content from message
  def thinking_content
    return nil unless has_thinking_content?
    match = content.match(/<thinking>(.*?)<\/thinking>|<think>(.*?)<\/think>/m)
    match[1] || match[2] if match
  end

  # Extract main content (without thinking)
  def main_content
    return content unless has_thinking_content?
    content.gsub(/<thinking>.*?<\/thinking>|<think>.*?<\/think>/m, "").strip
  end

  private

  def build_streaming_content(accumulated_content)
    # Check for thinking patterns
    if has_thinking_pattern?(accumulated_content)
      build_thinking_streaming_content(accumulated_content)
    else
      # Regular content without thinking
      ApplicationController.helpers.markdown_to_html(accumulated_content, dark_mode: false)
    end
  end

  def build_thinking_streaming_content(accumulated_content)
    thinking_content, main_content, is_thinking_complete = extract_streaming_thinking_content(accumulated_content)

    if thinking_content.present?
      thinking_html = ApplicationController.helpers.markdown_to_html(thinking_content, dark_mode: false)

      thinking_section = %(
        <details class="mb-3" #{is_thinking_complete ? '' : 'open'}>
          <summary class="cursor-pointer text-sm text-gray-600 hover:text-gray-800 flex items-center">
            <svg class="w-4 h-4 mr-1 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
            Thinking#{is_thinking_complete ? '...' : '... (ongoing)'}
          </summary>
          <div class="mt-2 pl-5 text-sm text-gray-700 bg-gray-50 rounded-lg p-3 border-l-4 border-gray-300">
            #{thinking_html}
            #{is_thinking_complete ? '' : '<span class="inline-block w-2 h-4 bg-gray-400 animate-pulse ml-1"></span>'}
          </div>
        </details>
      )

      if main_content.present?
        main_html = ApplicationController.helpers.markdown_to_html(main_content, dark_mode: false)
        "#{thinking_section}#{main_html}".html_safe
      elsif is_thinking_complete
        # Thinking is done but no main content yet
        "#{thinking_section}<span class=\"text-gray-500\">...</span>".html_safe
      else
        thinking_section.html_safe
      end
    else
      # Just started thinking, show loading
      '<span class="thinking text-gray-500">Thinking...</span>'.html_safe
    end
  end

  def extract_streaming_thinking_content(content)
    # Look for thinking tags (both open and potentially unclosed)
    if content.match?(/<thinking>(.*?)<\/thinking>/m)
      # Complete thinking block found
      match = content.match(/<thinking>(.*?)<\/thinking>(.*)/m)
      thinking_content = match[1]
      remaining_content = match[2]
      is_complete = true
    elsif content.match?(/<think>(.*?)<\/think>/m)
      # Complete think block found
      match = content.match(/<think>(.*?)<\/think>(.*)/m)
      thinking_content = match[1]
      remaining_content = match[2]
      is_complete = true
    elsif content.match?(/<thinking>(.*)/m)
      # Incomplete thinking block (still streaming)
      match = content.match(/<thinking>(.*)/m)
      thinking_content = match[1]
      remaining_content = ""
      is_complete = false
    elsif content.match?(/<think>(.*)/m)
      # Incomplete think block (still streaming)
      match = content.match(/<think>(.*)/m)
      thinking_content = match[1]
      remaining_content = ""
      is_complete = false
    else
      thinking_content = ""
      remaining_content = content
      is_complete = false
    end

    [ thinking_content&.strip, remaining_content&.strip, is_complete ]
  end

  def has_thinking_pattern?(content)
    content.match?(/<thinking>|<think>/)
  end
end
