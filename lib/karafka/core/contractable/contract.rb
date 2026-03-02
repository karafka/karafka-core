# frozen_string_literal: true

module Karafka
  module Core
    module Contractable
      # Base contract for all the contracts that check data format
      #
      # @note This contract does NOT support rules inheritance as it was never needed in Karafka
      class Contract
        extend Core::Configurable

        # Constant representing a miss during dig
        # We use it as a result value not to return an array with found object and a state to
        # prevent additional array allocation
        DIG_MISS = Object.new

        # Empty array for scope default to avoid allocating a new Array on each
        # `#call` / `#validate!` invocation. Safe because scope is never mutated – it is only
        # used in `scope + rule.path` which creates a new Array.
        EMPTY_ARRAY = [].freeze

        private_constant :DIG_MISS, :EMPTY_ARRAY

        # Yaml based error messages data
        setting(:error_messages)

        # Class level API definitions
        class << self
          # @return [Array<Rule>] all the validation rules defined for a given contract
          attr_reader :rules

          # Allows for definition of a scope/namespace for nested validations
          #
          # @param path [Symbol] path in the hash for nesting
          #
          # @example
          #   nested(:key) do
          #     required(:inside) { |inside| inside.is_a?(String) }
          #   end
          def nested(path, &)
            init_accu
            @nested << path
            instance_eval(&)
            @nested.pop
          end

          # Defines a rule for a required field (required means, that will automatically create an
          # error if missing)
          #
          # @param keys [Array<Symbol>] single or full path
          # @param block [Proc] validation rule
          def required(*keys, &block)
            init_accu
            @rules << Rule.new(@nested + keys, :required, block).freeze
          end

          # @param keys [Array<Symbol>] single or full path
          # @param block [Proc] validation rule
          def optional(*keys, &block)
            init_accu
            @rules << Rule.new(@nested + keys, :optional, block).freeze
          end

          # @param block [Proc] validation rule
          #
          # @note Virtual rules have different result expectations. Please see contracts or specs for
          #   details.
          def virtual(&block)
            init_accu
            @rules << Rule.new([], :virtual, block).freeze
          end

          private

          # Initializes nestings and rules building accumulator
          def init_accu
            @nested ||= []
            @rules ||= []
          end
        end

        # Runs the validation
        #
        # @param data [Hash] hash with data we want to validate
        # @param scope [Array<String>] scope of this contract (if any) or empty array if no parent
        #   scope is needed if contract starts from root
        # @return [Result] validaton result
        def call(data, scope: EMPTY_ARRAY)
          errors = []

          self.class.rules.each do |rule|
            case rule.type
            when :required
              validate_required(data, rule, errors, scope)
            when :optional
              validate_optional(data, rule, errors, scope)
            when :virtual
              validate_virtual(data, rule, errors, scope)
            end
          end

          Result.new(errors, self)
        end

        # @param data [Hash] data for validation
        # @param error_class [Class] error class that should be used when validation fails
        # @param scope [Array<String>] scope of this contract (if any) or empty array if no parent
        #   scope is needed if contract starts from root
        # @return [Boolean] true
        # @raise [StandardError] any error provided in the error_class that inherits from the
        #   standard error
        def validate!(data, error_class, scope: EMPTY_ARRAY)
          result = call(data, scope: scope)

          return true if result.success?

          raise error_class, result.errors
        end

        private

        # Runs validation for rules on fields that are required and adds errors (if any) to the
        # errors array
        #
        # @param data [Hash] input hash
        # @param rule [Rule] validation rule
        # @param errors [Array] array with errors from previous rules (if any)
        # @param scope [Array<String>]
        def validate_required(data, rule, errors, scope)
          for_checking = dig(data, rule.path)

          # We need to compare `DIG_MISS` against stuff because of the ownership of the `#==`
          # method
          if for_checking == DIG_MISS
            errors << [scope + rule.path, :missing]
          else
            result = rule.validator.call(for_checking, data, errors, self)

            return if result == true

            errors << [scope + rule.path, result || :format]
          end
        end

        # Runs validation for rules on fields that are optional and adds errors (if any) to the
        # errors array
        #
        # @param data [Hash] input hash
        # @param rule [Rule] validation rule
        # @param errors [Array] array with errors from previous rules (if any)
        # @param scope [Array<String>]
        def validate_optional(data, rule, errors, scope)
          for_checking = dig(data, rule.path)

          return if for_checking == DIG_MISS

          result = rule.validator.call(for_checking, data, errors, self)

          return if result == true

          errors << [scope + rule.path, result || :format]
        end

        # Runs validation for rules on virtual fields (aggregates, etc) and adds errors (if any) to
        # the errors array
        #
        # @param data [Hash] input hash
        # @param rule [Rule] validation rule
        # @param errors [Array] array with errors from previous rules (if any)
        # @param scope [Array<String>]
        def validate_virtual(data, rule, errors, scope)
          result = rule.validator.call(data, errors, self)

          return if result == true

          result&.each do |sub_result|
            sub_result[0] = scope + sub_result[0]
          end

          errors.push(*result)
        end

        # Tries to dig for a given key in a hash and returns it with indication whether or not it
        # was possible to find it (dig returns nil and we don't know if it wasn't the digged key
        # value)
        #
        # @param data [Hash]
        # @param keys [Array<Symbol>]
        # @return [DIG_MISS, Object] found element or DIGG_MISS indicating that not found
        def dig(data, keys)
          case keys.length
          when 1
            key = keys[0]

            return DIG_MISS unless data.key?(key)

            data[key]
          when 2
            key1 = keys[0]

            return DIG_MISS unless data.key?(key1)

            mid = data[key1]

            return DIG_MISS unless mid.is_a?(Hash) && mid.key?(keys[1])

            mid[keys[1]]
          else
            current = data

            keys.each do |nesting|
              return DIG_MISS unless current.key?(nesting)

              current = current[nesting]
            end

            current
          end
        end
      end
    end
  end
end
