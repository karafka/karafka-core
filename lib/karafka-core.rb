# frozen_string_literal: true

%w[
  yaml
  rdkafka

  concurrent/map
  concurrent/hash
  concurrent/array

  karafka/core
  karafka/core/version
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

  karafka/core/patches/rdkafka/bindings
].each { |dependency| require dependency }

# Karafka framework main namespace
module Karafka
end

# Patch rdkafka
::Rdkafka::Bindings.include(::Karafka::Core::Patches::Rdkafka::Bindings)
