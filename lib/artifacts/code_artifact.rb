module Artifacts
  class CodeArtifact < BaseArtifact
    def self.pattern
      /<code(?:\s[^>]*)?>/
    end

    def self.priority
      20 # Lower priority than thinking
    end

    def self.extract_tag_name(match)
      "code"
    end

    def render(dark_mode: false)
      language = attributes[:language] || "text"

      # Use markdown code block formatting for syntax highlighting
      code_markdown = "```#{language}\n#{content}\n```"
      content_html = markdown_to_html(code_markdown, dark_mode: dark_mode)

      status_indicator = complete ? "" : '<div class="text-xs text-gray-500 mt-1">Code streaming...</div>'

      %(
        <div class="artifact-code mb-3">
          <div class="bg-gray-900 text-gray-100 rounded-lg overflow-hidden">
            <div class="flex items-center justify-between px-4 py-2 bg-gray-800 border-b border-gray-700">
              <span class="text-xs font-medium text-gray-300">#{language.upcase}</span>
              <button class="text-xs text-gray-400 hover:text-gray-200 transition-colors" onclick="copyCode(this)">
                Copy
              </button>
            </div>
            <div class="p-4 text-sm font-mono overflow-x-auto">
              #{content_html}
            </div>
          </div>
          #{status_indicator}
        </div>
      ).html_safe
    end
  end
end

# Auto-register the artifact
Artifacts::ArtifactRegistry.register(Artifacts::CodeArtifact)
