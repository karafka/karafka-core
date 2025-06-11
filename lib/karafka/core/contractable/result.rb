# frozen_string_literal: true

module Karafka
  module Core
    module Contractable
      # Representation of a validaton result with resolved error messages
      class Result
        attr_reader :errors

        # Builds a result object and remaps (if needed) error keys to proper error messages
        #
        # @param errors [Array<Array>] array with sub-arrays with paths and error keys
        # @param contract [Object] contract that generated the error
        def initialize(errors, contract)
          # Short track to skip object allocation for the happy path
          if errors.empty?
            @errors = errors
            return
          end

          hashed = {}

          errors.each do |error|
            scope = error.first.map(&:to_s).join('.').to_sym

            # This will allow for usage of custom messages instead of yaml keys if needed
            hashed[scope] = if error.last.is_a?(String)
                              error.last
                            else
                              build_message(contract, scope, error.last)
                            end
          end

          @errors = hashed
        end

        # @return [Boolean] true if no errors
        def success?
          errors.empty?
        end

        private

        # Builds message based on the error messages and scope
        #
        # @param contract [Object] contract for which we build the result
        # @param scope [Symbol] path to the key that has an error
        # @param error_key [Symbol] error key for yaml errors lookup
        # @return [String] error message
        def build_message(contract, scope, error_key)
          messages = contract.class.config.error_messages

          # Split scope into parts for progressive checking
          scope_parts = scope.to_s.split('.')

          # Try full scope first, then progressively remove from beginning
          # This allows us to have full path scoped errors but can also be used as a fallback,
          # when scopes are dynamic. For example 'consumer_group_name.topic_name.name_format'
          (0..scope_parts.length).each do |i|
            current_scope_parts = scope_parts[i..]

            key = if current_scope_parts.empty?
                    error_key.to_s
                  else
                    "#{current_scope_parts.join('.')}_#{error_key}"
                  end

            return messages[key] if messages.key?(key)
          end

          # If nothing found, raise the original error
          messages.fetch(error_key.to_s) do
            messages.fetch("#{scope}_#{error_key}")
          end
        end
      end
    end
  end
end
