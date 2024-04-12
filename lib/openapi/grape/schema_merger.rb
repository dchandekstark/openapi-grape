module OpenAPI
  module Grape
    class SchemaMerger
      #
      # Merge multiple schemas into a single schema
      #
      # @param schemas [Array<Hash>] schemas to merge
      # @return [Hash] merged schema
      # @raise [ArgumentError] if no schemas are provided
      # @raise [TypeError] if any schema is not a Hash (when not a $ref)
      #
      def self.call(*schemas)
        raise ArgumentError, "At least one schema is required" if schemas.empty?

        to_merge = schemas.map { |schema| schema.key?("$ref") ? RefResolver.call(ref: schema["$ref"]) : schema }
        raise TypeError, "All arguments must be Hashes" unless to_merge.all? { |schema| schema.is_a?(Hash) }

        return to_merge.first if to_merge.size == 1

        to_merge.inject({}) do |merged, schema|
          merged.deep_merge(schema) do |_, oldval, newval|
            if oldval.is_a?(Array) && newval.is_a?(Array)
              oldval | newval
            else
              newval
            end
          end
        end
      end
    end
  end
end
