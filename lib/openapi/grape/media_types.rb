require "set"

module OpenAPI
  module Grape
    class MediaTypes
      #
      # Find all media types used in the API in responses under the given base path
      #
      # @param base_path [String] the base path for the routes
      # @return [Set<String>] media types used in the API
      #
      def self.call(base_path:)
        Set.new.tap do |media_types|
          PathFilter.call(base_path:).each_value do |path_item|
            path_item.slice(*Router::HTTP_METHODS).each_value do |operation|
              operation.fetch("responses", {}).each_value do |response|
                media_types.merge response.fetch("content", {}).keys
              end
            end
          end
        end
      end
    end
  end
end
