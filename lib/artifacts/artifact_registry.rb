module Artifacts
  class ArtifactRegistry
    @artifacts = []

    class << self
      # Register an artifact class
      def register(artifact_class)
        return if @artifacts.include?(artifact_class)

        unless artifact_class < BaseArtifact
          raise ArgumentError, "Artifact must inherit from BaseArtifact"
        end

        @artifacts << artifact_class
        # Sort by priority (lower numbers first)
        @artifacts.sort_by!(&:priority)
      end

      # Get all registered artifact classes
      def artifacts
        @artifacts.dup
      end

      # Find artifact classes that can handle the given content
      def find_handlers(content)
        @artifacts.select { |klass| klass.handles?(content) }
      end

      # Find the best handler for content (highest priority that matches)
      def find_best_handler(content)
        find_handlers(content).first
      end

      # Parse content and extract all artifacts
      def parse_artifacts(content)
        artifacts = []
        remaining_content = ""
        position = 0

        while position < content.length
          next_artifact = find_next_artifact(content, position)

          if next_artifact
            # Add any content before this artifact to remaining content
            if next_artifact[:start] > position
              remaining_content += content[position...next_artifact[:start]]
            end

            artifacts << next_artifact[:artifact]
            position = next_artifact[:end]
          else
            # No more artifacts, add rest to remaining content
            remaining_content += content[position..-1] if position < content.length
            break
          end
        end

        {
          artifacts: artifacts,
          remaining_content: remaining_content.strip
        }
      end

      # Clear all registered artifacts (useful for testing)
      def clear!
        @artifacts.clear
      end

      private

      def find_next_artifact(content, from_position)
        earliest_match = nil
        earliest_position = content.length

        @artifacts.each do |artifact_class|
          match = content.match(artifact_class.pattern, from_position)
          next unless match

          if match.begin(0) < earliest_position
            artifact = artifact_class.extract_from_match(content, match)

            artifact_info = {
              artifact: artifact,
              start: match.begin(0),
              end: artifact.complete ? find_closing_position(content, match, artifact_class) : content.length
            }

            if artifact_info[:start] < earliest_position
              earliest_match = artifact_info
              earliest_position = artifact_info[:start]
            end
          end
        end

        earliest_match
      end

      def find_closing_position(content, opening_match, artifact_class)
        tag_name = artifact_class.extract_tag_name(opening_match)
        closing_pattern = artifact_class.build_closing_pattern(tag_name)
        closing_match = content.match(closing_pattern, opening_match.end(0))

        closing_match ? closing_match.end(0) : content.length
      end
    end
  end
end
