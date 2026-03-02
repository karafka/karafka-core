# frozen_string_literal: true

module Karafka
  module Core
    module Monitoring
      # Many of the librdkafka statistics are absolute values instead of a gauge.
      # This means, that for example number of messages sent is an absolute growing value
      # instead of being a value of messages sent from the last statistics report.
      # This decorator calculates the diff against previously emited stats, so we get also
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

        def initialize
          @previous = EMPTY_HASH
          # Operate on ms precision only
          @previous_at = monotonic_now.round
          @current_at = @previous_at
          # Cache for memoized suffix keys to avoid repeated string allocations
          @suffix_keys_cache = {}
          # Pre-allocated buffer for pending hash writes to avoid per-hash Array allocations
          # that would otherwise be needed from `current.keys` when modifying hashes in-place
          @pending_writes = []
          @pw_size = 0
        end

        # @param emited_stats [Hash] original emited statistics
        # @return [Hash] emited statistics extended with the diff data
        # @note We modify the emited statistics, instead of creating new. Since we don't expose
        #   any API to get raw data, users can just assume that the result of this decoration is
        #   the proper raw stats that they can use
        def call(emited_stats)
          @current_at = monotonic_now.round

          @change_d = @current_at - @previous_at
          @pw_size = 0

          diff(
            @previous,
            emited_stats
          )

          @previous = emited_stats
          @previous_at = @current_at

          emited_stats.freeze
        end

        private

        # Calculates the diff of the provided values, appends delta and freeze duration keys,
        # and modifies in place the emited statistics.
        #
        # Uses `each_pair` with a reusable pending-writes buffer instead of `current.keys.each`
        # to avoid allocating a new Array for every Hash node in the statistics tree. At scale
        # (thousands of partitions), this eliminates tens of thousands of allocations per call.
        #
        # The append and suffix_keys_for logic is inlined to reduce method call overhead
        # (from ~915k method calls to ~39k at 6400 partitions).
        #
        # @param previous [Object] previous value from the given scope in which we are
        # @param current [Object] current scope from emitted statistics
        # @return [Object] the diff if the values were numerics or the current scope
        def diff(previous, current)
          if current.is_a?(Hash)
            filled_previous = previous || EMPTY_HASH
            mark = @pw_size
            cache = @suffix_keys_cache
            change_d = @change_d
            pw = @pending_writes
            pw_size = mark

            current.each_pair do |key, value|
              if value.is_a?(Hash)
                # Sync instance variable before recursing so nested calls use correct offset
                @pw_size = pw_size
                diff(filled_previous[key], value)
                next
              end

              next unless value.is_a?(Numeric)

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

              pw[pw_size] = pair[0]
              pw[pw_size + 1] = (result == 0) ? (filled_previous[pair[0]] || 0) + change_d : 0
              pw[pw_size + 2] = pair[1]
              pw[pw_size + 3] = result
              pw_size += 4
            end

            # Apply collected writes for this hash level
            @pw_size = pw_size
            i = mark
            while i < pw_size
              current[pw[i]] = pw[i + 1]
              i += 2
            end

            # Rewind buffer so parent level can continue from its mark
            @pw_size = mark
          end
        end
      end
    end
  end
end
