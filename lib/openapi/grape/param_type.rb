module OpenAPI
  module Grape
    #
    # Converts an OpenAPI/JSON schema type to a Grape parameter type
    #
    class ParamType
      # @return [Class, Array<Class>] the Grape type corresponding to the given OpenAPI/JSON schema
      def self.call(schema:, default: String)
        return default unless schema.present?

        # $ref resolution
        if schema.key?("$ref")
          ref = RefResolver.call(ref: schema["$ref"])
          return call(schema: ref, default:)
        end

        schema_type = schema.fetch("type", "string")
        if schema_type.is_a?(Array)
          schema_type = if schema_type.include?("array")
                          "array"
                        else
                          schema_type.detect { |t| t != "null" }
                        end
        end

        type = GRAPE_TYPE_MAP.fetch(schema_type) # raises KeyError if not found

        return GRAPE_STRING_FORMAT_MAP.fetch(schema["format"], String) if type == String && schema.key?("format")

        if type == Array
          subtype = call(schema: schema.fetch("items"))
          return [subtype]
        end

        type
      end
    end
  end
end
