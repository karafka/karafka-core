# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Single end config value representation
      Leaf = Struct.new(:name, :default, :constructor, :compiled, :lazy) do
        # @return [Boolean] true if already compiled
        def compiled?
          compiled
        end

        # @return [Boolean] is this a lazy evaluated leaf
        def lazy?
          lazy == true
        end
      end
    end
  end
end
