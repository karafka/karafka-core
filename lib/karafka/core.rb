# frozen_string_literal: true

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
