# frozen_string_literal: true

module Karafka
  module Core
    # Namespace for some small utilities used across the ecosystem
    module Helpers
      # Time related methods used across Karafka
      module Time
        # @return [Float] current monotonic time in milliseconds
        def monotonic_now
          ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)
        end

        # @return [Float] current time in float
        def float_now
          ::Process.clock_gettime(::Process::CLOCK_REALTIME)
        end
      end
    end
  end
end
