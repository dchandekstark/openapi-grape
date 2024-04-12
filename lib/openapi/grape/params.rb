module OpenAPI
  module Grape
    class Params
      CONTENT_TYPES = %w[application/json multipart/form-data].freeze

      attr_reader :api, :path_item, :http_method, :operation

      def self.call(api:, path_item:, http_method:, operation:)
        new(api:, path_item:, http_method:, operation:).params
      end

      def initialize(api:, path_item:, http_method:, operation:)
        @api = api
        @path_item = path_item
        @http_method = http_method
        @operation = operation
      end

      def request_body_params
        return [] unless %w[post patch put].include?(http_method) && operation["requestBody"]

        request_body = operation["requestBody"]
        content = request_body.fetch("content") # content is required by OAPI spec
        content_type = content.keys.first # has only one key

        unless CONTENT_TYPES.include?(content_type)
          raise NotImplementedError,
                "Unsupported request body content type: #{content_type.inspect}"
        end

        schema = content.dig(content_type, "schema") || {}
        schema = RefResolver.call(ref: schema["$ref"]) if schema.key?("$ref")
        schema = SchemaMerger.call(*schema["allOf"]) if schema.key?("allOf")

        properties = schema.fetch("properties", {}).reject { |_, prop| prop.fetch("readOnly", false) }
        return [] if properties.empty?

        type = ParamType.call(schema:)

        if content_type == "application/json" && type != OBJECT_TYPE
          raise NotImplementedError,
                "Unsupported JSON request body schema type: #{type.inspect}"
        end

        properties.map do |name, prop|
          Param.from_schema(schema: prop, name:).tap do |param|
            param.required! if schema.fetch("required", []).include?(name)

            # file param
            param.options[:type] = ::File if content_type == "multipart/form-data" && content.dig(content_type,
                                                                                                  "encoding", name, "contentType") == "application/octet-stream"

            api.logger.debug do
              "[API] Adding #{param.required ? "required" : "optional"} request body param #{param.name.inspect} #{param.options.inspect}"
            end
          end
        end
      end

      def params
        path_item_params = path_item.fetch("parameters", []).map { |p| Param.from_oapi(oapi_param: p) }
        operation_params = operation.fetch("parameters", []).map { |p| Param.from_oapi(oapi_param: p) }
        path_item_params + operation_params + request_body_params
      end
    end
  end
end
