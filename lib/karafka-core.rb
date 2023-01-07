# frozen_string_literal: true

%w[
  yaml
  rdkafka

  concurrent/map
  concurrent/hash
  concurrent/array

  karafka/core
  karafka/core/version

  karafka/core/helpers/time

  karafka/core/monitoring
  karafka/core/monitoring/event
  karafka/core/monitoring/monitor
  karafka/core/monitoring/notifications
  karafka/core/monitoring/statistics_decorator

  karafka/core/configurable
  karafka/core/configurable/leaf
  karafka/core/configurable/node

  karafka/core/contractable/contract
  karafka/core/contractable/result
  karafka/core/contractable/rule

  karafka/core/instrumentation
  karafka/core/instrumentation/callbacks_manager

  karafka/core/patches/rdkafka/bindings
].each { |dependency| require dependency }

# Karafka framework main namespace
module Karafka
end

# Patch rdkafka
::Rdkafka::Bindings.include(::Karafka::Core::Patches::Rdkafka::Bindings)

# Rdkafka uses a single global callback for things. We bypass that by injecting a manager for
# each callback type. Callback manager allows us to register more than one callback
# @note Those managers are also used by Karafka for consumer related statistics
::Rdkafka::Config.statistics_callback = ::Karafka::Core::Instrumentation.statistics_callbacks
::Rdkafka::Config.error_callback = ::Karafka::Core::Instrumentation.error_callbacks
