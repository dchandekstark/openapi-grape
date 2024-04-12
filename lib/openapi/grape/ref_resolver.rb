require "net/http"
require "json"
require "yaml"

module OpenAPI
  module Grape
    class RefResolver
      # @param ref [String]
      # @param doc [Hash] a JSON schema or OpenAPI document
      # @return [Hash] the resolved reference
      def self.call(ref:, doc:, depth: 0)
        return doc if ref.blank?

        raise "Max depth exceeded resolving ref: #{ref}" if depth > REF_RESOLVER_MAX_DEPTH

        # Local doc ref
        if m = %r{^\#/(.*)}.match(ref)
          parts = m[1].split("/").map { |part| part.gsub("~1", "/").gsub("~0", "~") }
          resolved = doc.dig(*parts)

          raise "Unable to resolve ref: #{ref}" if resolved.nil?

          if resolved.is_a?(Hash) && resolved.key?("$ref")
            return RefResolver.call(ref: resolved["$ref"], doc:,
                                    depth: depth + 1)
          end

          return resolved
        end

        # DDR-specific, by convention - pull schema directly, not over http
        # if m = %r{^/api/schemas/(\w+)(\.json)?}.match(ref)
        #   return Ddr::API::Schema.load_schema(m[1])
        # end

        # External ref
        if /^https?:/.match?(ref)
          uri = URI(ref)
          response = Net::HTTP.get_response(uri, { "accept" => "application/json, application/yaml" })
          response.value # raises error if not success

          # raises error if not valid JSON or YAML
          remote_doc = response["content-type"] == "application/json" ? JSON.parse(response.body) : YAML.safe_load(response.body)

          # resolve fregment if present
          if fragment = uri.fragment
            return RefResolver.call(ref: fragment, doc: remote_doc, depth: depth + 1)
          end

          return remote_doc
        end

        raise "Unable to resolve ref: #{ref}"
      end
    end
  end
end
