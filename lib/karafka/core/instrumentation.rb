# frozen_string_literal: true

module Karafka
  module Core
    # All the instrumentation shared across Karafka ecosystem
    module Instrumentation
      class << self
        # Builds a manager for statistics callbacks
        # @return [WaterDrop::CallbacksManager]
        def statistics_callbacks
          @statistics_callbacks ||= CallbacksManager.new
        end

        # Builds a manager for error callbacks
        # @return [WaterDrop::CallbacksManager]
        def error_callbacks
          @error_callbacks ||= CallbacksManager.new
        end
      end
    end
  end
end
