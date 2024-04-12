# frozen_string_literal: true

require_relative "grape/version"
require "grape"

module OpenAPI
  module Grape
    class Error < StandardError; end

    Path = ->(path:) { path.gsub(/\{([^}]+)\}/, ':\1') }

    PathFilter = ->(doc:, base_path:) { doc.fetch("paths").select { |key, _| key.start_with?(base_path) } }
  end
end

require_relative "grape/param_type"
