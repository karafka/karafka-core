# frozen_string_literal: true

module Karafka
  module Core
    module Helpers
      # Kafka related helpers
      module Kafka
        # Reads librdkafka configuration values the way the ecosystem acts on them
        module Config
          # Values that turn a librdkafka boolean setting on
          ENABLED_VALUES = [true, "true"].freeze

          private_constant :ENABLED_VALUES

          class << self
            # @param value [Object] librdkafka boolean setting value (e.g. from a `kafka` hash)
            # @return [Boolean] true only when the value is `true` or `"true"`
            # @note Any other value, including `nil` (setting not provided) and `"false"`, is false
            def enabled?(value)
              ENABLED_VALUES.include?(value)
            end
          end
        end
      end
    end
  end
end
