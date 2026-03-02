# frozen_string_literal: true

module Karafka
  module Core
    module Monitoring
      # Single notification event wrapping payload with id
      class Event
        attr_reader :id

        # @param id [String, Symbol] id of the event
        # @param payload [Hash] event payload
        # @param time [Float, nil] execution time, stored separately to avoid eager hash
        #   allocation. Merged into the payload lazily only when `#payload` is accessed.
        def initialize(id, payload, time = nil)
          @id = id
          @raw_payload = payload
          @time = time
          @payload = nil
        end

        # @return [Hash] full payload including time (if set). The merged hash is built lazily
        #   on first access to avoid allocating a new Hash when listeners only use `#[]`.
        def payload
          @payload ||= if @time
            @raw_payload.empty? ? { time: @time } : @raw_payload.merge(time: @time)
          else
            @raw_payload
          end
        end

        # Hash access to the payload data (if present)
        # Provides direct access to time without triggering payload hash construction.
        #
        # @param name [String, Symbol]
        def [](name)
          return @time if name == :time && @time

          @raw_payload.fetch(name)
        end
      end
    end
  end
end
