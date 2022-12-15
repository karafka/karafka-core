# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Single end config value representation
      Leaf = Struct.new(:name, :default, :constructor, :compiled) do
        # @return [Boolean] true if already compiled
        def compiled?
          compiled
        end
      end
    end
  end
end
