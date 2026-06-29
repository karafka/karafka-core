# frozen_string_literal: true

module Karafka
  module Core
    # Karafka instrumentation related shared components
    module Instrumentation
      # This manager allows us to register multiple callbacks into a hook that is suppose to support
      # a single callback
      class CallbacksManager
        # @return [::Karafka::Core::Instrumentation::CallbacksManager]
        def initialize
          @callbacks = {}
          @values = [].freeze
          @mutex = Mutex.new
        end

        # Invokes all the callbacks registered one after another
        #
        # @param args [Object] any args that should go to the callbacks
        # @note Copy-on-write: dispatch iterates an immutable snapshot that `add`/`delete`
        #   rebuild and swap in under a mutex. Because `#call` never mutates shared state, it
        #   needs neither a lock nor a per-call `#values` allocation, and a callback registered
        #   or removed from another thread is never lost; it just takes effect on the next
        #   `#call`. A cache invalidated from within `#call` could not be updated atomically
        #   against this read, so a stale write-back would permanently drop callbacks.
        def call(*args)
          @values.each { |callback| callback.call(*args) }
        end

        # Adds a callback to the manager
        #
        # @param id [String] id of the callback (used when deleting it)
        # @param callable [#call] object that responds to a `#call` method
        def add(id, callable)
          @mutex.synchronize do
            @callbacks[id] = callable
            @values = @callbacks.values.freeze
          end
        end

        # Removes the callback from the manager
        # @param id [String] id of the callback we want to remove
        def delete(id)
          @mutex.synchronize do
            @callbacks.delete(id)
            @values = @callbacks.values.freeze
          end
        end
      end
    end
  end
end
