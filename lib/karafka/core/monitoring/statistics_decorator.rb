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
        # @param only_keys [Array<String>] when set, only these numeric keys will be decorated
        #   with delta/freeze duration suffixes. Hash children are still recursed into for
        #   structural navigation, but only the listed keys receive _d and _fd computation.
        #   This drastically reduces work at the partition level where most cost occurs.
        #   When empty (default), all numeric keys are decorated.
        def initialize(excluded_keys: [], only_keys: [])
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
          # Frozen array for direct-access decoration, nil when empty to use full decoration
          @only_keys = unless only_keys.empty?
            only_keys.freeze
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
        # When @only_keys is set, uses a two-phase approach: first recurse into hash
        # children for structural navigation, then decorate only the specified keys via
        # direct hash access (no iteration over non-target keys). This drastically reduces
        # work at the partition level where most of the cost occurs.
        #
        # When @only_keys is nil, uses full decoration: iterates all keys, decorating every
        # numeric value found.
        #
        # @param previous [Object] previous value from the given scope in which we are
        # @param current [Object] current scope from emitted statistics
        # @param change_d [Integer] time delta in ms since last stats emission
        def diff(previous, current, change_d)
          return unless current.is_a?(Hash)

          if @only_keys
            diff_only_keys(previous, current, change_d)
          else
            diff_all(previous, current, change_d)
          end
        end

        # Full decoration path: iterates all keys, decorating every numeric value.
        #
        # Uses `keys.each` to snapshot the current hash's key list, allowing direct writes
        # to the hash during iteration without a pending-writes buffer.
        #
        # Checks Numeric before Hash because ~80% of statistics values are numeric.
        #
        # @param previous [Object] previous value from the given scope
        # @param current [Hash] current scope from emitted statistics
        # @param change_d [Integer] time delta in ms
        def diff_all(previous, current, change_d)
          filled_previous = previous || EMPTY_HASH
          cache = @suffix_keys_cache
          excluded = @excluded_keys

          current.keys.each do |key|
            next if excluded&.key?(key)

            value = current[key]

            if value.is_a?(Numeric)
              prev_value = filled_previous[key]

              if prev_value.nil?
                result = 0
              elsif prev_value.is_a?(Numeric)
                result = value - prev_value
              else
                next
              end

              pair = cache[key] || (cache[key] = ["#{key}_fd".freeze, "#{key}_d".freeze].freeze)

              current[pair[0]] = (result == 0) ? (filled_previous[pair[0]] || 0) + change_d : 0
              current[pair[1]] = result
            elsif value.is_a?(Hash)
              diff_all(filled_previous[key], value, change_d)
            end
          end
        end

        # Known librdkafka statistics tree structural keys. Used by diff_only_keys to
        # navigate directly to known hash paths instead of iterating all keys.
        KNOWN_HASH_KEYS = { "brokers" => true, "topics" => true, "cgrp" => true }.freeze

        # Known structural keys within a topic hash
        TOPIC_HASH_KEYS = { "partitions" => true }.freeze

        private_constant :KNOWN_HASH_KEYS, :TOPIC_HASH_KEYS

        # Selective decoration path: navigates known librdkafka statistics tree structure
        # directly instead of iterating all keys to find hash children. Decorates only the
        # specified keys via direct access at each level.
        #
        # This eliminates the generic recursion overhead (72,000+ is_a?(Hash) checks at the
        # partition level alone on a 2000-partition cluster) by leveraging knowledge of the
        # librdkafka statistics layout: root → brokers → broker, root → topics → topic →
        # partitions → partition, root → cgrp.
        #
        # For non-librdkafka hash children (e.g. custom or test data), falls back to generic
        # recursion to maintain correctness with arbitrary nested structures.
        #
        # @param previous [Object] previous value from the given scope
        # @param current [Hash] current stats hash (root level)
        # @param change_d [Integer] time delta in ms
        def diff_only_keys(previous, current, change_d)
          filled_previous = previous || EMPTY_HASH
          excluded = @excluded_keys

          # Root level decoration
          decorate_keys(current, filled_previous, change_d)

          # Brokers: each child is a broker hash (leaf-like for only_keys)
          unless excluded&.key?("brokers")
            brokers = current["brokers"]

            if brokers.is_a?(Hash)
              prev_brokers = filled_previous["brokers"] || EMPTY_HASH

              brokers.each_pair do |name, broker|
                decorate_keys(broker, prev_brokers[name] || EMPTY_HASH, change_d) if broker.is_a?(Hash)
              end
            end
          end

          # Topics → Partitions
          unless excluded&.key?("topics")
            topics = current["topics"]

            if topics.is_a?(Hash)
              prev_topics = filled_previous["topics"] || EMPTY_HASH

              topics.each_pair do |name, topic|
                next unless topic.is_a?(Hash)

                prev_topic = prev_topics[name] || EMPTY_HASH
                decorate_keys(topic, prev_topic, change_d)

                unless excluded&.key?("partitions")
                  partitions = topic["partitions"]

                  if partitions.is_a?(Hash)
                    prev_partitions = prev_topic["partitions"] || EMPTY_HASH

                    decorate_partitions(partitions, prev_partitions, change_d)
                  end
                end
              end
            end
          end

          # Consumer group (leaf-like)
          cgrp = current["cgrp"]
          decorate_keys(cgrp, filled_previous["cgrp"] || EMPTY_HASH, change_d) if cgrp.is_a?(Hash)

          # Fallback: handle any non-standard hash children not in the known structure.
          # This ensures correctness for arbitrary nested data while the known paths above
          # provide the fast path for real librdkafka statistics.
          current.each_pair do |key, value|
            next if KNOWN_HASH_KEYS.key?(key)
            next if excluded&.key?(key)
            next unless value.is_a?(Hash)

            diff_only_keys_generic(filled_previous[key], value, change_d)
          end
        end

        # Generic recursive fallback for only_keys mode on non-standard hash children.
        # Used for hash subtrees not covered by the known librdkafka structure.
        #
        # @param previous [Object] previous value
        # @param current [Hash] current hash to process
        # @param change_d [Integer] time delta in ms
        def diff_only_keys_generic(previous, current, change_d)
          return unless current.is_a?(Hash)

          filled_previous = previous || EMPTY_HASH
          excluded = @excluded_keys

          decorate_keys(current, filled_previous, change_d)

          current.each_pair do |key, value|
            next if excluded&.key?(key)

            diff_only_keys_generic(filled_previous[key], value, change_d) if value.is_a?(Hash)
          end
        end

        # Decorates partitions within a topic. Extracted as a method so subclasses can
        # override to filter which partitions are decorated (e.g. skip unassigned partitions
        # in a consumer context).
        #
        # @param partitions [Hash] partition id => partition stats hash
        # @param prev_partitions [Hash] previous partition stats
        # @param change_d [Integer] time delta in ms
        def decorate_partitions(partitions, prev_partitions, change_d)
          partitions.each_pair do |pid, partition|
            decorate_keys(partition, prev_partitions[pid] || EMPTY_HASH, change_d)
          end
        end

        # Decorates only the keys listed in @only_keys via direct hash access.
        # No iteration over the full hash, no type checking on non-target keys.
        #
        # @param current [Hash] current stats node
        # @param filled_previous [Hash] previous stats node
        # @param change_d [Integer] time delta in ms
        def decorate_keys(current, filled_previous, change_d)
          cache = @suffix_keys_cache
          only = @only_keys

          only.each do |key|
            value = current[key]

            next unless value.is_a?(Numeric)

            prev_value = filled_previous[key]

            if prev_value.nil?
              result = 0
            elsif prev_value.is_a?(Numeric)
              result = value - prev_value
            else
              next
            end

            pair = cache[key] || (cache[key] = ["#{key}_fd".freeze, "#{key}_d".freeze].freeze)

            current[pair[0]] = (result == 0) ? (filled_previous[pair[0]] || 0) + change_d : 0
            current[pair[1]] = result
          end
        end
      end
    end
  end
end
