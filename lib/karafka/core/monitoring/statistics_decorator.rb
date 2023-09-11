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
        end

        # @param emited_stats [Hash] original emited statistics
        # @return [Hash] emited statistics extended with the diff data
        # @note We modify the emited statistics, instead of creating new. Since we don't expose
        #   any API to get raw data, users can just assume that the result of this decoration is
        #   the proper raw stats that they can use
        def call(emited_stats)
          @current_at = monotonic_now.round

          @change_d = @current_at - @previous_at

          diff(
            @previous,
            emited_stats
          )

          @previous = emited_stats
          @previous_at = @current_at

          emited_stats.freeze
        end

        private

        # Calculates the diff of the provided values and modifies in place the emited statistics
        #
        # @param previous [Object] previous value from the given scope in which
        #   we are
        # @param current [Object] current scope from emitted statistics
        # @return [Object] the diff if the values were numerics or the current scope
        def diff(previous, current)
          if current.is_a?(Hash)
            filled_previous = previous || EMPTY_HASH
            filled_current = current || EMPTY_HASH

            # @note We cannot use #each_key as we modify the content of the current scope
            #   in place (in case it's a hash)
            current.keys.each do |key|
              append(
                filled_previous,
                filled_current,
                key,
                diff(filled_previous[key], filled_current[key])
              )
            end
          end

          # Diff can be computed only for numerics
          return current unless current.is_a?(Numeric)
          # If there was no previous value, delta is always zero
          return 0 unless previous
          # Should never happen but just in case, a type changed in between stats
          return current unless previous.is_a?(Numeric)

          current - previous
        end

        # Appends the result of the diff to a given key as long as the result is numeric
        #
        # @param previous [Hash] previous scope
        # @param current [Hash] current scope
        # @param key [Symbol] key based on which we were diffing
        # @param result [Object] diff result
        def append(previous, current, key, result)
          return unless result.is_a?(Numeric)
          return if current.frozen?

          freeze_duration_key = "#{key}_fd"

          if result.zero?
            current[freeze_duration_key] = previous[freeze_duration_key] || 0
            current[freeze_duration_key] += @change_d
          else
            current[freeze_duration_key] = 0
          end

          current["#{key}_d"] = result
        end
      end
    end
  end
end
