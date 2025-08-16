module Artifacts
  class ToolUseArtifact < BaseArtifact
    def self.pattern
      /<tool_use(?:\s[^>]*)?>/
    end

    def self.priority
      30
    end

    def self.extract_tag_name(match)
      "tool_use"
    end

    def render(dark_mode: false)
      tool_name = attributes[:name] || "Unknown Tool"
      status_indicator = complete ? "" : '<div class="text-xs text-blue-600 mt-1">Tool executing...</div>'

      %(
        <div class="artifact-tool-use mb-3 bg-blue-50 border border-blue-200 rounded-lg p-3">
          <div class="flex items-center mb-2">
            <svg class="w-4 h-4 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            </svg>
            <span class="text-sm font-medium text-blue-800">Tool Use: #{escape_html(tool_name)}</span>
          </div>
          <pre class="text-xs text-blue-700 bg-blue-100 p-2 rounded overflow-x-auto whitespace-pre-wrap">#{escape_html(content)}</pre>
          #{status_indicator}
        </div>
      ).html_safe
    end
  end
end

# Auto-register the artifact
Artifacts::ArtifactRegistry.register(Artifacts::ToolUseArtifact)
