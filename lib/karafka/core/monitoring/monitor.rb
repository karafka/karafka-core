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
        # Empty has to save on objects allocation
        EMPTY_HASH = {}.freeze

        private_constant :EMPTY_HASH

        # @param notifications_bus [Object] either our internal notifications bus or
        #   `ActiveSupport::Notifications`
        # @param namespace [String, nil] namespace for events or nil if no namespace
        def initialize(notifications_bus, namespace = nil)
          @notifications_bus = notifications_bus
          @namespace = namespace
          @mapped_events = {}
        end

        # Passes the instrumentation block (if any) into the notifications bus
        #
        # @param event_id [String, Symbol] event id
        # @param payload [Hash]
        # @param block [Proc] block we want to instrument (if any)
        def instrument(event_id, payload = EMPTY_HASH, &block)
          full_event_name = @mapped_events[event_id] ||= [event_id, @namespace].compact.join('.')

          @notifications_bus.instrument(full_event_name, payload, &block)
        end

        # Allows us to subscribe to the notification bus
        #
        # @param args [Array] any arguments that the notification bus subscription layer accepts
        # @param block [Proc] optional block for subscription
        def subscribe(*args, &block)
          @notifications_bus.subscribe(*args, &block)
        end

        # Allows for removal of whatever was subscribed
        #
        # @param listener_or_block [Object] object that is subscribed whether this is a listener
        #   instance or a block.
        def unsubscribe(listener_or_block)
          @notifications_bus.unsubscribe(listener_or_block)
        end

        # @return [Hash<String, Array>] hash where keys are events and values are arrays with
        #   listeners subscribed to particular events. Since different events may have different
        #   listeners, this is returned that way.
        #
        # @note Please do not modify this hash. It should be used only for debugging.
        #
        # @example If you need to get only classes of listeners, you can run following code:
        #   monitor.listeners.map(&:class)
        def listeners
          @notifications_bus.listeners
        end
      end
    end
  end
end
