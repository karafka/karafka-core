# frozen_string_literal: true

module Karafka
  module Core
    module Monitoring
      # A simple notifications layer for Karafka ecosystem that aims to provide API compatible
      # with both `ActiveSupport::Notifications` and `dry-monitor`.
      #
      # We do not use any of them by default as our use-case is fairly simple and we do not want
      # to have too many external dependencies.
      class Notifications
        include Core::Helpers::Time

        attr_reader :name

        # Raised when someone wants to publish event that was not registered
        EventNotRegistered = Class.new(StandardError)

        # Empty hash for internal referencing
        EMPTY_HASH = {}.freeze

        private_constant :EMPTY_HASH

        def initialize
          @listeners = {}
          @mutex = Mutex.new
          # This allows us to optimize the method calling lookups
          @events_methods_map = {}
          @active_events = {}
        end

        # Registers a new event on which we can publish
        #
        # @param event_id [String] event id
        def register_event(event_id)
          @mutex.synchronize do
            @listeners[event_id] = []
            @events_methods_map[event_id] = :"on_#{event_id.to_s.tr('.', '_')}"
          end
        end

        # Clears all the subscribed listeners. If given an event, only clear listeners for the given
        # event type.
        # @param event_id [String] the key of the event to clear listeners for.
        def clear(event_id = nil)
          @mutex.synchronize do
            return @listeners.each_value(&:clear) unless event_id
            return @listeners[event_id].clear if @listeners.key?(event_id)

            raise(EventNotRegistered, "#{event_id} not registered!")
          end
        end

        # Allows for subscription to an event
        # There are two ways you can subscribe: via block or via listener.
        #
        # @param event_id_or_listener [Object] event id when we want to subscribe to a particular
        #   event with a block or listener if we want to subscribe with general listener
        # @param block [Proc] block of code if we want to subscribe with it
        #
        # @example Subscribe using listener
        #   subscribe(MyListener.new)
        #
        # @example Subscribe via block
        #   subscribe do |event|
        #     puts event
        #   end
        def subscribe(event_id_or_listener, &block)
          @mutex.synchronize do
            if block
              event_id = event_id_or_listener

              raise EventNotRegistered, event_id unless @listeners.key?(event_id)

              @listeners[event_id] << block
            else
              listener = event_id_or_listener

              @listeners.each_key do |reg_event_id|
                next unless listener.respond_to?(@events_methods_map[reg_event_id])

                @listeners[reg_event_id] << listener
              end
            end
          end
        end

        # Allows for code instrumentation
        # Runs the provided code and sends the instrumentation details to all registered listeners
        #
        # @param event_id [String] id of the event
        # @param payload [Hash] payload for the instrumentation
        # @yield [Proc] instrumented code
        # @return [Object] whatever the provided block (if any) returns
        #
        # @example Instrument some code
        #   instrument('sleeping') do
        #     sleep(1)
        #   end
        def instrument(event_id, payload = EMPTY_HASH)
          assigned_listeners = @listeners[event_id]

          # Allow for instrumentation of only events we registered. If listeners array does not
          # exist, it means the event was not registered.
          raise EventNotRegistered, event_id unless assigned_listeners

          if block_given?
            # No point in instrumentation when no one is listening
            # Since the outcome will be ignored, we may as well save on allocations
            # There are many events that happen often like (`message.acknowledged`) that most
            # users do not subscribe to. Such check prevents us from publishing events that would
            # not be used at all saving on time measurements and objects allocations
            return yield if assigned_listeners.empty?

            start = monotonic_now
            result = yield
            time = monotonic_now - start
          else
            # Skip measuring or doing anything if no one listening
            return if assigned_listeners.empty?
          end

          event = Event.new(
            event_id,
            time ? payload.merge(time: time) : payload
          )

          assigned_listeners.each do |listener|
            if listener.is_a?(Proc)
              listener.call(event)
            else
              listener.send(@events_methods_map[event_id], event)
            end
          end

          result
        end
      end
    end
  end
end
