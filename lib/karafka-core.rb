# frozen_string_literal: true

%w[
  logger
  yaml
  rdkafka

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

  karafka/core/taggable
  karafka/core/taggable/tags

  karafka/core/patches/rdkafka/bindings
].each { |dependency| require dependency }

# Karafka framework main namespace
module Karafka
end

# Patch rdkafka
::Rdkafka::Bindings.include(::Karafka::Core::Patches::Rdkafka::Bindings)

instrumentation = ::Karafka::Core::Instrumentation
rd_config = ::Rdkafka::Config

# Rdkafka uses a single global callback for things. We bypass that by injecting a manager for
# each callback type. Callback manager allows us to register more than one callback
# @note Those managers are also used by Karafka for consumer related statistics
rd_config.statistics_callback = instrumentation.statistics_callbacks
rd_config.error_callback = instrumentation.error_callbacks
rd_config.oauthbearer_token_refresh_callback = instrumentation.oauthbearer_token_refresh_callbacks

# This loads librdkafka components into memory prior to initializing the client.
# This mitigates macos forking issues.
# @see https://github.com/confluentinc/librdkafka/issues/4590
::Rdkafka::Bindings.rd_kafka_global_init if ::Rdkafka::Bindings.respond_to?(:rd_kafka_global_init)
