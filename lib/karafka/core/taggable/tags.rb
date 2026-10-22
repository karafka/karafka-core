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
          @mutex = Mutex.new
          @snapshot = Snapshot.new({}.freeze, []).freeze
        end

        # Adds a tag with a given name to tags
        # @param name [Symbol] name we want to use for a given tag
        # @param tag [#to_s] any object that can be converted into a string via `#to_s`
        def add(name, tag)
          value = tag.to_s

          @mutex.synchronize { publish(@snapshot.tags.merge(name => value)) }
        end

        # Removes all the tags
        def clear
          @mutex.synchronize { publish({}) }
        end

        # Removes a tag with a given name
        # @param name [Symbol] name of the tag
        def delete(name)
          @mutex.synchronize { publish(@snapshot.tags.except(name)) }
        end

        # @return [Array<String>] all unique tags registered
        def to_a
          @snapshot.values
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

        private

        # Replaces the snapshot with one built from the given tags. Readers do not lock, so the tags
        # are never changed in place: each write publishes a new snapshot in one assignment.
        #
        # @param tags [Hash{Symbol => String}] all the tags after the change
        # @return [Snapshot] the published snapshot
        def publish(tags)
          @snapshot = Snapshot.new(tags.freeze, tags.values.uniq).freeze
        end
      end
    end
  end
end
