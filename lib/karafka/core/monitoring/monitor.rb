# frozen_string_literal: true

module Karafka
  module Core
    module Monitoring
      # Karafka monitor that can be used to pass through instrumentation calls to selected
      # notifications bus.
      #
      # It provides abstraction layer that allows us to use both our internal notifications as well
      # as `ActiveSupport::Notifications`.
      class Monitor
        # Empty hash to save on objects allocation
        EMPTY_HASH = {}.freeze

        private_constant :EMPTY_HASH

        # @param notifications_bus [Object] either our internal notifications bus or
        #   `ActiveSupport::Notifications`
        # @param namespace [String, nil] namespace for events or nil if no namespace
        def initialize(notifications_bus, namespace = nil)
          @notifications_bus = notifications_bus
          @namespace = namespace
          @mapped_events = {}
          @mutex = Mutex.new
        end

        # Passes the instrumentation block (if any) into the notifications bus
        #
        # @param event_id [String, Symbol] event id
        # @param payload [Hash]
        def instrument(event_id, payload = EMPTY_HASH, &)
          # With no namespace, string event ids already are the full event names. This is the
          # case for all the events in the Karafka ecosystem, so we can skip the mapping hash
          # lookup on this hot path. Symbols still go through the mapping to be converted into
          # strings without allocating on each call.
          full_event_name = if @namespace.nil? && event_id.is_a?(String)
            event_id
          else
            @mapped_events[event_id] || map_event(event_id)
          end

          @notifications_bus.instrument(full_event_name, payload, &)
        end

        # Allows us to subscribe to the notification bus
        def subscribe(*, &)
          @notifications_bus.subscribe(*, &)
        end

        # Allows for removal of whatever was subscribed
        #
        # @param listener_or_block [Object] object that is subscribed whether this is a listener
        #   instance or a block.
        def unsubscribe(listener_or_block)
          @notifications_bus.unsubscribe(listener_or_block)
        end

        # @return [Hash{String => Array}] hash where keys are events and values are arrays with
        #   listeners subscribed to particular events. Since different events may have different
        #   listeners, this is returned that way.
        #
        # @example If you need to get only classes of listeners, you can run following code:
        #   monitor.listeners.map(&:class)
        #
        # @note Please do not modify this hash. It should be used only for debugging.
        def listeners
          @notifications_bus.listeners
        end

        private

        # Builds and caches the full event name for an event id
        #
        # @param event_id [String, Symbol] event id
        # @return [String] full event name
        def map_event(event_id)
          @mutex.synchronize do
            # Copy-on-write: #instrument reads the Hash without the lock and on JRuby a Hash that
            # is written by many threads at once can get corrupted, so we replace it instead.
            @mapped_events[event_id] || begin
              full_event_name = [event_id, @namespace].compact.join(".")
              @mapped_events = @mapped_events.merge(event_id => full_event_name).freeze
              full_event_name
            end
          end
        end
      end
    end
  end
end
