# frozen_string_literal: true

module Karafka
  module Core
    module Contractable
      # Representation of a single validation rule
      Rule = Struct.new(:path, :type, :validator)
    end
  end
end
