# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Base class for config defaults injectors.
      #
      # An injector enriches a config-like hash with a set of default values, applying each
      # default only when the corresponding key is not already present. This lets a component
      # ship sane defaults while still letting users override any of them by pre-populating the
      # key themselves.
      #
      # Injectors are meant to be layered. A base (e.g. OSS) injector defines its {defaults} and
      # an extension (e.g. Pro) prepends a module onto the singleton class and calls `super` to
      # contribute additional defaults on top:
      #
      #   Base.singleton_class.prepend(Extension)
      #
      # The only-if-absent rule applies to the target being enriched, not to the defaults
      # themselves: a key the user already set in the target is never touched. How two layers
      # resolve a key they both define is up to the layers -- e.g. an extension using
      # `super.merge(extra)` lets its own value win, while `extra.merge(super)` would keep the
      # base value.
      #
      # @example Define an injector with defaults
      #   class MyInjector < Karafka::Core::Configurable::Injector
      #     DEFAULTS = { 'a' => 1, 'b' => 2 }.freeze
      #
      #     class << self
      #       def defaults
      #         DEFAULTS
      #       end
      #     end
      #   end
      #
      #   MyInjector.call({ 'b' => 20 }) #=> { 'b' => 20, 'a' => 1 }
      #
      # @example Layer extra defaults (e.g. Pro) via prepend + super
      #   module ProDefaults
      #     def defaults
      #       super.merge('c' => 3)
      #     end
      #   end
      #
      #   MyInjector.singleton_class.prepend(ProDefaults)
      #   MyInjector.call({}) #=> { 'a' => 1, 'b' => 2, 'c' => 3 }
      #
      # @note The base class holds no state and defines no defaults on its own; it is not useful
      #   directly and is expected to be subclassed. Subclasses should return the same defaults
      #   object (e.g. a frozen constant) on each call so that a prepended layer doing
      #   `super.merge(...)` never mutates it.
      class Injector
        class << self
          # Enriches the target with the defaults, without overwriting any key that is already
          # present in it. The target is mutated in place.
          #
          # @param target [Hash] config hash to enrich in place
          # @return [Hash] the same target, enriched with the missing defaults
          def call(target)
            defaults.each do |key, value|
              next if target.key?(key)

              target[key] = value
            end

            target
          end

          # @return [Hash] default values to inject. Override in subclasses; extensions may
          #   prepend a module onto the singleton class and call `super` to contribute additional
          #   defaults on top.
          def defaults
            {}
          end
        end
      end
    end
  end
end
