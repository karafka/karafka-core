# frozen_string_literal: true

module Karafka
  module Core
    module Monitoring
      # Many of the librdkafka statistics are absolute values instead of a gauge.
      # This means, that for example number of messages sent is an absolute growing value
      # instead of being a value of messages sent from the last statistics report.
      # This decorator calculates the diff against previously emitted stats, so we get also
      # the diff together with the original values
      #
      # It adds two extra values to numerics:
      #   - KEY_d - delta of the previous value and current
      #   - KEY_fd - freeze duration - describes how long the delta remains unchanged (zero)
      #              and can be useful for detecting values that "hang" for extended period of time
      #              and do not have any change (delta always zero). This value is in ms for the
      #              consistency with other time operators we use.
      class StatisticsDecorator
        include Helpers::Time

        # Empty hash for internal referencing
        EMPTY_HASH = {}.freeze

        private_constant :EMPTY_HASH

        # @param excluded_keys [Array<String>] list of key names to skip entirely during
        #   decoration. Excluded keys are not recursed into and not decorated with delta/freeze
        #   duration suffixes. This is useful for skipping large subtrees of the librdkafka
        #   statistics that are not consumed by the application (e.g. broker toppars, window
        #   stats like int_latency, outbuf_latency, throttle, batchsize, batchcnt, req).
        def initialize(excluded_keys: [])
          @previous = EMPTY_HASH
          # Operate on ms precision only
          @previous_at = monotonic_now.round
          # Cache for memoized suffix keys to avoid repeated string allocations
          @suffix_keys_cache = {}
          # Frozen hash for O(1) key exclusion lookup, nil when empty to avoid per-key
          # lookups in the hot loop when no exclusions are configured
          @excluded_keys = unless excluded_keys.empty?
            excluded_keys.each_with_object({}) { |k, h| h[k] = true }.freeze
          end
        end

        # @param emitted_stats [Hash] original emitted statistics
        # @return [Hash] emitted statistics extended with the diff data
        # @note We modify the emitted statistics, instead of creating new. Since we don't expose
        #   any API to get raw data, users can just assume that the result of this decoration is
        #   the proper raw stats that they can use
        def call(emitted_stats)
          current_at = monotonic_now.round
          change_d = current_at - @previous_at

          diff(
            @previous,
            emitted_stats,
            change_d
          )

          @previous = emitted_stats
          @previous_at = current_at

          emitted_stats.freeze
        end

        private

        # Calculates the diff of the provided values and modifies the emitted statistics
        # in place to add delta and freeze duration keys.
        #
        # Uses `keys.each` to snapshot the current hash's key list, allowing direct writes
        # to the hash during iteration. This eliminates the pending-writes buffer and
        # write-back loop, yielding ~13% faster performance at scale compared to the
        # `each_pair` + buffer approach.
        #
        # The suffix_keys_for logic is inlined to reduce method call overhead.
        #
        # Checks Numeric before Hash because ~80% of statistics values are numeric, avoiding
        # a wasted is_a?(Hash) branch on the majority of iterations.
        #
        # @param previous [Object] previous value from the given scope in which we are
        # @param current [Object] current scope from emitted statistics
        # @param change_d [Integer] time delta in ms since last stats emission
        def diff(previous, current, change_d)
          return unless current.is_a?(Hash)

          filled_previous = previous || EMPTY_HASH
          cache = @suffix_keys_cache
          excluded = @excluded_keys

          # keys creates a snapshot array, allowing direct hash writes during iteration
          # without the overhead of a pending-writes buffer and write-back loop
          current.keys.each do |key|
            next if excluded&.key?(key)

            value = current[key]

            # Numeric-first: most values in librdkafka statistics are numeric, so checking
            # Numeric before Hash avoids a wasted is_a?(Hash) on ~80% of iterations
            if value.is_a?(Numeric)
              prev_value = filled_previous[key]

              if prev_value.nil?
                result = 0
              elsif prev_value.is_a?(Numeric)
                result = value - prev_value
              else
                next
              end

              # Inlined suffix_keys_for for reduced method call overhead
              pair = cache[key] || (cache[key] = ["#{key}_fd".freeze, "#{key}_d".freeze].freeze)

              current[pair[0]] = (result == 0) ? (filled_previous[pair[0]] || 0) + change_d : 0
              current[pair[1]] = result
            elsif value.is_a?(Hash)
              diff(filled_previous[key], value, change_d)
            end
          end
        end
      end
    end
  end
end
