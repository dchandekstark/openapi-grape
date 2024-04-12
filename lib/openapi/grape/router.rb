require "uri"

module OpenAPI
  module Grape
    class Router

      attr_reader :api, :doc, :base_path

      # @param api [Grape::API] the Grape API to generate routes for
      # @param base_path [String] the base path for the routes
      def initialize(api:, doc:, base_path: nil)
        @api = api
        @doc = doc
        @base_path = base_path || api.base_path
      end

      def operation_desc(operation:)
        description = operation["description"] || operation["summary"]
        api.desc description if description
      end

      def operation_params(path_item:, http_method:, operation:, grape_path:)
        grape_params = Params.call(api:, path_item:, http_method:, operation:)
        api.params do
          grape_params.each do |param|
            param_method = method(param.required ? :requires : :optional)
            block = nil
            if param.nested.any?
              block = proc do
                requires(
                  :none,
                  except: param.nested.select(&:required).map(&:name),
                  using: param.nested.map { |nested_param| [nested_param.name, nested_param.options] }.to_h
                )
              end
            end
            # ::Rails.logger.info { "[API] Adding #{param.required ? 'required' : 'optional'} param to endpoint #{http_method.upcase} #{grape_path} -- #{param.name.inspect} #{param.options.inspect}" }
            param_method.call(param.name, param.options, &block)
          end
        end
      end

      def is_replaced_by_route(http_method:, grape_path:, operation:)
        replaced_by = is_replaced_by(operation:)

        new_operation = if replaced_by.key?("operationId")
                          FindOperation.call(http_methods: ["get"], operation_id: replaced_by["operationId"])
                        else
                          ref = replaced_by["operationRef"]
                          op = RefResolver.call(ref:)
                          m = %r{\#/paths/[^/]+/get\z}.match(ref)
                          raise "Invalid operationRef: #{ref}" unless m

                          # https://spec.openapis.org/oas/latest.html#runtime-expressions
                          new_path = m[1].gsub("~1", "/").gsub("~0", "~")
                          { path: new_path, http_method: "get", operation: op }
                        end

        new_grape_path = Path.call(path: new_operation[:path])
        new_params = replaced_by.fetch("parameters", {})

        new_path_params = new_params.select { |_name, loc| loc.start_with?("$request.path.") } # .keys.map(&:to_sym)
        new_path_params.transform_values! { |loc| loc.sub("$request.path.", "") }

        new_query_params = new_params.select { |_name, loc| loc.start_with?("$request.query.") } # .keys.map(&:to_sym)
        new_query_params.transform_values! { |loc| loc.sub("$request.query.", "") }

        base_url = doc.fetch("servers").first.fetch("url") # FIXME: assumes only one server

        helper_method_name = operation.fetch("operationId").to_sym

        api.route(http_method, grape_path) do
          warn "[API] [DEPRECATION] Operation GET #{grape_path} is deprecated; " \
              "use GET #{new_grape_path} instead.",
               category: :deprecated

          if respond_to?(helper_method_name) # use helper method if available
            helper_method = method(helper_method_name) # raises NameError
            helper_method.call
          else # otherwise, redirect to new route
            new_url = base_url + new_grape_path.gsub(/:(\w+)/, '%{\1}') # :id => %{id}
            # Use the locations (values) from new_params to get the values from the request
            new_url %= params.slice(*new_path_params.values).symbolize_keys if new_path_params.any?
            new_url += "?" + URI.encode_www_form(params.slice(*new_query_params.values)) if new_query_params.any?
            redirect new_url, permanent: true
          end
        end
      end

      def is_replaced_by?(http_method:, operation:)
        http_method == "get" && deprecated?(operation:) && is_replaced_by(operation:).present?
      end

      def is_replaced_by(operation:)
        operation.dig("responses", "301", "links", "isReplacedBy")
      end

      def deprecated?(operation:)
        operation.fetch("deprecated", false)
      end

      def operation_route(http_method:, grape_path:, operation:)
        api.route(http_method, grape_path) do
          deprecated_route! if operation.fetch("deprecated", false)
          helper_method = method operation.fetch("operationId").to_sym # raises NameError if method not found
          helper_method.call
        end
      end

      def operation_endpoint(http_method:, path_item:, operation:, grape_path:)
        api.logger.info { "[API] Generating endpoint for #{http_method.upcase} #{grape_path}" }

        operation_desc(operation:)
        operation_params(path_item:, http_method:, operation:, grape_path:)

        return is_replaced_by_route(http_method:, grape_path:, operation:) if is_replaced_by?(http_method:, operation:)

        operation_route(http_method:, grape_path:, operation:)
      end

      def path_item_routes(path:, path_item:)
        grape_path = Path.call(path:)
        http_methods = path_item.slice(*HTTP_METHODS) # ignore head, trace, options
        http_methods.each do |http_method, operation|
          operation_endpoint(http_method:, path_item:, operation:, grape_path:)
        end
      end

      def paths
        doc.fetch("paths").select { |path, _| path.start_with?(base_path) }
      end

      def generate_routes!
        paths.each do |path, path_item|
          path_item_routes(path:, path_item:)
        end
      end
    end
  end
end
