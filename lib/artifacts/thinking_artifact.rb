module Artifacts
  class ThinkingArtifact < BaseArtifact
    def self.pattern
      /<(thinking|think)(?:\s[^>]*)?>/
    end

    def self.priority
      10 # High priority for thinking artifacts
    end

    def self.extract_tag_name(match)
      match[1] # Either "thinking" or "think"
    end

    def self.build_closing_pattern(tag_name)
      # Handle both thinking and think closing tags
      /<\/(thinking|think)>/
    end

    def render(dark_mode: false)
      content_html = markdown_to_html(content, dark_mode: dark_mode)
      status_text = complete ? "Thinking..." : "Thinking... (ongoing)"
      open_state = complete ? "" : "open"
      pulse_indicator = complete ? "" : '<span class="inline-block w-2 h-4 bg-gray-400 animate-pulse ml-1"></span>'

      %(
        <details class="mb-3 artifact-thinking" #{open_state}>
          <summary class="cursor-pointer text-sm text-gray-600 hover:text-gray-800 flex items-center">
            <svg class="w-4 h-4 mr-1 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
            #{status_text}
          </summary>
          <div class="mt-2 pl-5 text-sm text-gray-700 bg-gray-50 rounded-lg p-3 border-l-4 border-gray-300">
            #{content_html}#{pulse_indicator}
          </div>
        </details>
      ).html_safe
    end
  end
end

# Auto-register the artifact
Artifacts::ArtifactRegistry.register(Artifacts::ThinkingArtifact)
