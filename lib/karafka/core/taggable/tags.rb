# frozen_string_literal: true

module Karafka
  module Core
    module Taggable
      # This allows us to collect tags about given object. We attach name to each tag, because we
      # may want to replace given tag with a different one and we need to have a reference of
      # what we want to replace
      class Tags
        # Creates new tags accumulator
        def initialize
          @accu = {}
        end

        # Adds a tag with a given name to tags
        # @param name [Symbol] name we want to use for a given tag
        # @param tag [#to_s] any object that can be converted into a string via `#to_s`
        def add(name, tag)
          @accu[name] = tag.to_s
        end

        # Removes all the tags
        def clear
          @accu.clear
        end

        # Removes a tag with a given name
        # @param name [Symbol] name of the tag
        def delete(name)
          @accu.delete(name)
        end

        # @return [Array<String>] all unique tags registered
        def to_a
          @accu.values.tap(&:uniq!)
        end

        # @param _args [Object] anything that the standard `to_json` accepts
        # @return [String] json representation of tags
        def to_json(*_args)
          to_a.to_json
        end

        # @param _args [Object] anything that the standard `as_json` accepts
        # @return [Array<String>] array that can be converted to json
        def as_json(*_args)
          to_a
        end
      end
    end
  end
end
