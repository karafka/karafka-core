# frozen_string_literal: true

require 'logger'
require 'yaml'
require 'rdkafka'
require 'karafka/core'
require 'karafka/core/version'
require 'karafka/core/helpers/time'
require 'karafka/core/monitoring'
require 'karafka/core/monitoring/event'
require 'karafka/core/monitoring/monitor'
require 'karafka/core/monitoring/notifications'
require 'karafka/core/monitoring/statistics_decorator'
require 'karafka/core/configurable'
require 'karafka/core/configurable/leaf'
require 'karafka/core/configurable/node'
require 'karafka/core/contractable/contract'
require 'karafka/core/contractable/result'
require 'karafka/core/contractable/rule'
require 'karafka/core/instrumentation'
require 'karafka/core/instrumentation/callbacks_manager'
require 'karafka/core/taggable'
require 'karafka/core/taggable/tags'
require 'karafka/core/patches/rdkafka/bindings'

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
