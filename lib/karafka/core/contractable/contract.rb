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
        # `#call` / `#validate!` invocation. Safe because scope is never mutated - it is only
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

          # Defines a virtual rule that validates the whole data rather than a single key. Unlike
          # `required`/`optional`, the block receives the full data and returns its own errors.
          #
          # @param block [Proc] validation rule, called with `(data, errors, contract)`. It must
          #   return either a non-Array (`true`/`nil`/`false`) for "no errors", or an `Array` of
          #   `[path, message]` error pairs (where `path` is itself an `Array` of symbols).
          #
          # @note The returned error `Array` is owned by the contract: `#call` prepends the current
          #   scope onto each pair in place and collects them, so a rule must return a freshly
          #   built `Array` on every call. Returning a memoized, shared or frozen `Array` is not
          #   supported -- in-place scoping would accumulate the prefix across validations (or
          #   raise `FrozenError`). Build the result in the block (e.g. `[[%i[id], :invalid]]`)
          #   rather than returning a constant.
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
        # The per-rule handling is inlined instead of dispatching to per-type methods because
        # this runs per rule per validation, including the per-message validations in
        # WaterDrop. Required and optional rules share the whole flow except the missing-key
        # handling. `DIG_MISS` is compared via `#equal?` so we never dispatch `#==` to the
        # validated (user-provided) values.
        #
        # @param data [Hash] hash with data we want to validate
        # @param scope [Array<String>] scope of this contract (if any) or empty array if no parent
        #   scope is needed if contract starts from root
        # @return [Result] validaton result
        def call(data, scope: EMPTY_ARRAY)
          errors = []

          self.class.rules.each do |rule|
            if rule.type == :virtual
              result = rule.validator.call(data, errors, self)

              # A virtual rule signals "no errors" with any non-Array result (true, but also a
              # falsy `nil`/`false` returned by e.g. `condition && [[...], :err]`). Only an Array
              # of error pairs is iterated; previously a `false` return reached `false.each` and
              # raised NoMethodError (a `nil` return was already tolerated by the safe navigation).
              next unless result.is_a?(Array)

              # Apply the scope prefix in place on the rule's returned pairs and collect them
              # directly. Per the `virtual` contract the rule hands back a freshly built Array
              # each call (see `DSL#virtual`), so mutating it here is safe and avoids allocating a
              # new pair per error.
              result.each do |sub_result|
                sub_result[0] = scope + sub_result[0]
              end

              errors.push(*result)
            else
              for_checking = dig(data, rule.path)

              if DIG_MISS.equal?(for_checking)
                errors << [scope + rule.path, :missing] if rule.type == :required
              else
                result = rule.validator.call(for_checking, data, errors, self)

                next if result == true

                errors << [scope + rule.path, result || :format]
              end
            end
          end

          return Result.success if errors.empty?

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

        # Tries to dig for a given key in a hash and returns it with indication whether or not it
        # was possible to find it (dig returns nil and we don't know if it wasn't the digged key
        # value)
        #
        # Uses `Hash#fetch` with the `DIG_MISS` sentinel as the default, which resolves presence
        # and value in a single hash lookup instead of a `key?` check followed by `[]`. This
        # runs per rule per validation, including the per-message validations in WaterDrop,
        # hence the lookup count matters. `fetch` with a default ignores `default_proc`, same
        # as the previous `key?` based logic.
        #
        # @param data [Hash]
        # @param keys [Array<Symbol>]
        # @return [DIG_MISS, Object] found element or DIGG_MISS indicating that not found
        def dig(data, keys)
          case keys.length
          when 1
            data.fetch(keys[0], DIG_MISS)
          when 2
            mid = data.fetch(keys[0], DIG_MISS)

            return DIG_MISS if DIG_MISS.equal?(mid)
            return DIG_MISS unless mid.is_a?(Hash)

            mid.fetch(keys[1], DIG_MISS)
          else
            current = data

            keys.each do |nesting|
              return DIG_MISS unless current.is_a?(Hash)

              current = current.fetch(nesting, DIG_MISS)

              return DIG_MISS if DIG_MISS.equal?(current)
            end

            current
          end
        end
      end
    end
  end
end
