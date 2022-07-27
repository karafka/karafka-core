# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Single end config value representation
      Leaf = Struct.new(:name, :default, :constructor)
    end
  end
end
