# frozen_string_literal: true

require_relative "grape/version"
require "grape"
require "json"

module OpenAPI
  module Grape
    class Error < StandardError; end

    Path = ->(path:) { path.gsub(/\{([^}]+)\}/, ':\1') }

    PathFilter = ->(doc:, base_path:) { doc.fetch("paths").select { |key, _| key.start_with?(base_path) } }

    CSVSplitter = ->(val) { val.split(",") }

    HTTP_METHODS = %w[get put post delete patch].freeze

    REF_RESOLVER_MAX_DEPTH = 10 # max depth to resolve refs, to prevent infinite loops

    OBJECT_TYPE = JSON

    GRAPE_TYPE_MAP = {
      "string" => String,
      "integer" => Integer,
      "number" => Float,
      "boolean" => ::Grape::API::Boolean,
      "array" => Array,
      "object" => OBJECT_TYPE,
      "null" => nil
    }.freeze

    GRAPE_STRING_FORMAT_MAP = {
      "date-time" => DateTime,
      "date" => Date,
      "time" => Time
    }.freeze
  end
end

require_relative "grape/ref_resolver"
require_relative "grape/schema_merger"
require_relative "grape/param_type"
require_relative "grape/param"
require_relative "grape/params"
require_relative "grape/find_operation"
require_relative "grape/media_types"
require_relative "grape/router"
