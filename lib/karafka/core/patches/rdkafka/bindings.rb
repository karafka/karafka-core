# frozen_string_literal: true

module Karafka
  module Core
    # Patches to dependencies and components
    module Patches
      # Patches to rdkafka
      module Rdkafka
        # Extends `Rdkafka::Bindings` with some extra methods and updates callbacks that we intend
        # to work with in a bit different way than rdkafka itself
        module Bindings
          class << self
            # Add extra methods that we need
            # @param mod [::Rdkafka::Bindings] rdkafka bindings module
            def included(mod)
              # Default rdkafka setup for errors doest not propagate client details, thus it always
              # publishes all the stuff for all rdkafka instances. We change that by providing
              # function that fetches the instance name, allowing us to have better notifications
              mod.send(:remove_const, :ErrorCallback)
              mod.const_set(:ErrorCallback, build_error_callback)
            end

            # @return [FFI::Function] overwritten callback function
            def build_error_callback
              FFI::Function.new(
                :void, %i[pointer int string pointer]
              ) do |client_ptr, err_code, reason, _opaque|
                return nil unless ::Rdkafka::Config.error_callback

                # Guard against a null client pointer. librdkafka can invoke the error callback
                # with a NULL `rd_kafka_t` (e.g. very early in client construction), and calling
                # `rd_kafka_name` on it dereferences the pointer and segfaults the whole process.
                # Mirrors the upstream `ErrorCallback`.
                name = client_ptr.null? ? nil : ::Rdkafka::Bindings.rd_kafka_name(client_ptr)

                # Resolve fatal errors to their underlying cause. `ERR__FATAL` is only a generic
                # marker; the real error code and description must be fetched from librdkafka via
                # `rd_kafka_fatal_error` (done by `RdkafkaError.build_fatal`). Without this the
                # callback would report the generic fatal code instead of the actual error.
                # Mirrors the upstream `ErrorCallback`.
                error = if err_code == ::Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL
                  ::Rdkafka::RdkafkaError.build_fatal(
                    client_ptr,
                    fallback_error_code: err_code,
                    fallback_message: reason,
                    instance_name: name
                  )
                else
                  ::Rdkafka::RdkafkaError.new(err_code, broker_message: reason)
                end

                error.set_backtrace(caller)

                ::Rdkafka::Config.error_callback.call(name, error)
              end
            end
          end
        end
      end
    end
  end
end
