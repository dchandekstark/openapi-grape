module OpenAPI
  module Grape
    class FindOperation
      #
      # Find an operation by its operationId
      #
      # @param doc [Hash] OpenAPI document
      # @param operation_id [String] operationId to find
      # @param http_methods [Array<String>] HTTP methods to search through
      # @return [Hash] operation details
      # @raise [OpenAPI::Grape::Error] if operation not found
      def self.call(doc:, operation_id:, http_methods: Router::HTTP_METHODS)
        doc.fetch("paths").each do |path, path_item|
          path_item.slice(*http_methods).each do |http_method, operation|
            return { path:, http_method:, operation: } if operation.fetch("operationId") == operation_id
          end
        end

        raise Error, "Operation not found: #{operation_id}"
      end
    end
  end
end
