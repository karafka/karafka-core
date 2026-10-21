# frozen_string_literal: true

module Karafka
  module Core
    module Taggable
      # Tags by name and their unique values, published together so a reader never sees one
      # without the other
      Snapshot = Struct.new(:tags, :values)
    end
  end
end
