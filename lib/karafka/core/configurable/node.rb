# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Single non-leaf node
      # This is a core component for the configurable settings
      #
      # The idea here is simple: we collect settings (leafs) and children (nodes) information and
      # we only compile/initialize the values prior to user running the `#configure` API. This API
      # needs to run prior to using the result stuff even if there is nothing to configure
      class Node
        attr_reader :name, :nestings

        # We need to be able to redefine children for deep copy
        attr_accessor :children

        # @param name [Symbol] node name
        # @param nestings [Proc] block for nested settings
        def initialize(name, nestings = ->(_) {})
          @name = name
          @children = []
          @nestings = nestings
          @compiled = false
          instance_eval(&nestings)
        end

        # Allows for a single leaf or nested node definition
        #
        # @param name [Symbol] setting or nested node name
        # @param default [Object] default value
        # @param constructor [#call, nil] callable or nil
        # @param lazy [Boolean] is this a lazy leaf
        # @param block [Proc] block for nested settings
        def setting(name, default: nil, constructor: nil, lazy: false, &block)
          @children << if block
                         Node.new(name, block)
                       else
                         Leaf.new(name, default, constructor, false, lazy)
                       end

          compile
        end

        # Allows for the configuration and setup of the settings
        #
        # Compile settings, allow for overrides via yielding
        # @return [Node] returns self after configuration
        def configure
          compile if !@compiled || name == :root
          yield(self) if block_given?
          self
        end

        # @return [Hash] frozen config hash representation
        def to_h
          config = {}

          @children.each do |value|
            config[value.name] = if value.is_a?(Leaf)
                                   result = public_send(value.name)
                                   # We need to check if value is not a result node for cases where
                                   # we merge additional config
                                   result.is_a?(Node) ? result.to_h : result
                                 else
                                   value.to_h
                                 end
          end

          config.freeze
        end

        # Deep copies all the children nodes to allow us for templates building on a class level
        # and non-side-effect usage on an instance/inherited.
        # @return [Node] duplicated node
        def deep_dup
          dupped = Node.new(name, nestings)

          dupped.children += children.map do |value|
            if value.is_a?(Leaf)
              # After inheritance we need to reload the state so the leafs are recompiled again
              value = value.dup
              value.compiled = false
              value
            else
              value.deep_dup
            end
          end

          dupped
        end

        # Converts the settings definitions into end children
        # @note It runs once, after things are compiled, they will not be recompiled again
        def compile
          @children.each do |value|
            # Do not redefine something that was already set during compilation
            # This will allow us to reconfigure things and skip override with defaults
            skippable = respond_to?(value.name)
            lazy_leaf = value.is_a?(Leaf) && value.lazy?

            # Do not create accessor for leafs that are lazy as they will get a custom method
            # created instead
            singleton_class.attr_accessor(value.name) unless lazy_leaf

            next if skippable

            initialized = if value.is_a?(Leaf)
                            next if value.compiled?

                            value.compiled = true
                            value.constructor ? value.constructor.call(value.default) : value.default
                          else
                            value.compile
                            value
                          end

            if lazy_leaf && !initialized
              build_dynamic_accessor(value)
            else
              public_send("#{value.name}=", initialized)
            end
          end

          @compiled = true
        end

        private

        # Defines a lazy evaluated accessor that will re-evaluate in case value constructor
        # evaluates to `nil` or `false`. This allows us to define dynamic constructors that
        # can react to external conditions to become expected value once this value is
        # available
        #
        # @param value [Leaf]
        def build_dynamic_accessor(value)
          define_singleton_method(value.name) do
            existing = instance_variable_get("@#{name}")

            return existing if existing

            built = value.constructor.call(value.default)

            instance_variable_set("@#{name}", built)
          end
        end
      end
    end
  end
end
