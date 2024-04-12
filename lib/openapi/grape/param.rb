module OpenAPI
  module Grape
    class Param
      UUID_RE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
      EMAIL_RE = /\A[\w\-.]+@[\w\-.]+\z/ # close enough

      attr_accessor :name, :required, :options, :nested

      def initialize(name:, required: false, options: {}, nested: [])
        @name = name
        @required = required
        @options = options
        @nested = nested
      end

      def required!
        self.required = true
        options[:allow_blank] = false
      end

      # @param schema [Hash] a JSON schema object
      # @param name [String] the name of the parameter
      # @param skip_read_only [Boolean] whether to skip read-only properties
      # @return [Param] a Param object
      def self.from_schema(schema:, name:, skip_read_only: false)
        schema = SchemaMerger.call(schema["allOf"]) if schema.key?("allOf")
        schema = RefResolver.call(ref: schema["$ref"]) if schema.key?("$ref")
        required = schema["required"] || schema.dig("items", "required") || []

        new(name: name.to_sym, options: param_options(schema:), nested: []).tap do |param|
          param.required! if required.include?(name)

          param.nested = nested_params(schema:, skip_read_only:) if [OBJECT_TYPE, [OBJECT_TYPE]].include?(param.options[:type])
        end
      end

      # @param oapi_param [Hash] an OAPI parameter object
      # @return [Param] a Param object
      def self.from_oapi(oapi_param:)
        param = oapi_param.dup

        # $ref resolution
        param = RefResolver.call(ref: param["$ref"]) if param.key?("$ref")
        schema = param.fetch("schema", {})

        new(name: param.fetch("name").to_sym, options: param_options(schema:), nested: []).tap do |_param|
          _param.required! if param.fetch("required", false)

          # handle OAPI comma-separated query param values
          if _param.options[:type] == [String] && param["in"] == "query" &&
             param["style"] == "form" && param["explode"] == false
            _param.options[:coerce_with] = CSVSplitter
          end

          _param.nested = nested_params(schema:) if [Hash, [Hash]].include?(_param.options[:type])
        end
      end

      # @param schema [Hash] a JSON schema object
      # @param skip_read_only [Boolean] whether to skip read-only properties
      # @return [Array<Param>] an array of Param objects
      def self.nested_params(schema:, skip_read_only: false)
        [].tap do |nested_props|
          properties = schema["properties"] || schema.dig("items", "properties") || {}
          required = schema["required"] || schema.dig("items", "required") || []

          properties.each do |name, prop|
            next if skip_read_only && prop.fetch("readOnly", false)

            nested_prop = from_schema(schema: prop, name:, skip_read_only:)
            nested_prop.required! if required.include?(name)
            nested_props << nested_prop
          end
        end
      end

      # @param schema [Hash] a JSON schema object
      # @return [Hash] Grape param options
      def self.param_options(schema:)
        type = ParamType.call(schema:)

        { type:,
          desc: schema["description"],
          default: schema["default"],
          values: schema["enum"] || schema.dig("items", "enum"),
          allow_blank: false }.compact.tap do |options|
          if [String, [String]].include?(type) && format = schema["format"] || schema.dig("items", "format")
            # N.B. 'date', 'date-time', and 'time' formats are handled in OpenAPI::Grape::ParamType
            options[:regexp] = UUID_RE if format == "uuid"
            options[:regexp] = EMAIL_RE if format == "email"
          end
        end
      end
    end
  end
end
