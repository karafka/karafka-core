# frozen_string_literal: true

# `#gem_root` returns a `Pathname`, so the dependency must be loaded explicitly rather than
# relying on Bundler or another gem to have required it first.
require "pathname"

module Karafka
  # Namespace for small support modules used throughout the Karafka ecosystem
  module Core
    class << self
      # @return [String] root path of this gem
      def gem_root
        Pathname.new(File.expand_path("../..", __dir__))
      end
    end
  end
end
