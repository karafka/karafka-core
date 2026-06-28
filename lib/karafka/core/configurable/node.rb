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
        attr_reader :node_name, :nestings

        # We need to be able to redefine children for deep copy
        attr_accessor :children

        # Names that cannot be used as setting names because they would collide with the node
        # internal state or the node public API: their accessors would shadow the node own
        # readers (breaking for example `#deep_dup` or `#to_h`) and writers like `children=`
        # would overwrite internal ivars. `#setting` and `#register` reject them upfront and
        # `#ivar_backed?` keeps guarding the ivar mirror as defense in depth.
        # Private method names are deliberately not reserved: that would make internal
        # implementation details part of the public contract
        RESERVED_NAMES = %i[
          node_name
          children
          nestings
          compiled
          configs_refs
          local_defs
          setting
          configure
          to_h
          deep_dup
          register
          compile
        ].to_h { |name| [name, true] }.freeze

        # Setting names that match this format can be backed by instance variables and use the
        # fast `attr_reader` based readers. Others (e.g. registered names with dashes) fall back
        # to the hash-based accessors
        IVAR_NAMEABLE_FORMAT = /\A[A-Za-z_][A-Za-z0-9_]*\z/

        private_constant :RESERVED_NAMES, :IVAR_NAMEABLE_FORMAT

        class << self
          # Builds each node through its own anonymous subclass. Since setting values are
          # mirrored into instance variables for fast access and each node layout carries a
          # different set of them, instantiating nodes directly from this class would grow its
          # object shape variations past the Ruby limit, degrading ivar access for all nodes.
          # A subclass per layout keeps shape variations per class minimal (late `setting`
          # calls after inheritance or runtime `register` calls may add a few more, staying
          # well under the limit). `#deep_dup` reuses the subclass of its template, so
          # duplicated configs share shapes as well.
          def new(...)
            equal?(Node) ? Class.new(self).new(...) : super
          end
        end

        # @param node_name [Symbol] node name
        # @param nestings [Proc] block for nested settings
        # @param evaluate [Boolean] when false, skip evaluating the nestings block. Used by
        #   deep_dup to avoid re-creating children that will be overwritten immediately.
        def initialize(node_name, nestings = ->(_) {}, evaluate: true)
          @node_name = node_name
          @children = []
          @nestings = nestings
          @compiled = false
          @configs_refs = {}
          @local_defs = {}
          instance_eval(&nestings) if evaluate
        end

        # Allows for a single leaf or nested node definition
        #
        # @param node_name [Symbol, String] setting or nested node name
        # @param default [Object] default value
        # @param constructor [#call, nil] callable or nil
        # @param lazy [Boolean] is this a lazy leaf
        # @param block [Proc] block for nested settings
        # @raise [ArgumentError] when the name is reserved for the node internal state
        def setting(node_name, default: nil, constructor: nil, lazy: false, &block)
          # Symbolize at definition time (same as `#register`) so the config store, accessors,
          # `#to_h` and the compile state checks all agree on the key type also when a String
          # name is provided
          node_name = node_name.to_sym

          prevent_reserved_names!(node_name)

          @children << if block
            Node.new(node_name, block)
          else
            Leaf.new(node_name, default, constructor, false, lazy)
          end

          compile
        end

        # Allows for the configuration and setup of the settings
        #
        # Compile settings, allow for overrides via yielding
        # @return [Node] returns self after configuration
        def configure
          compile if !@compiled || node_name == :root
          yield(self) if block_given?
          self
        end

        # @return [Hash] frozen config hash representation
        def to_h
          config = {}

          @children.each do |value|
            config[value.node_name] = if value.is_a?(Leaf)
              result = if @configs_refs.key?(value.node_name)
                @configs_refs[value.node_name]
              elsif value.constructor
                value.constructor.call
              elsif value.default
                value.default
              end

              # We need to check if value is not a result node for cases
              # where we merge additional config
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
          # Same-layout nodes reuse the class of their template so they share object shapes
          dupped = self.class.new(node_name, nestings, evaluate: false)

          children.each do |value|
            dupped.children << if value.is_a?(Leaf)
              # After inheritance we need to reload the state so the leafs are recompiled again
              value = value.dup
              value.compiled = false

              # `Struct#dup` is intentionally shallow here: the leaf's `default` value is shared by
              # reference across the class template and every config instance produced by
              # `deep_dup`. This is the contract -- one uniform rule for all default types -- and it
              # is what lets a shared service object passed as a default (e.g. a logger) keep its
              # identity across all configs instead of being cloned per instance. The flip side is
              # that an in-place mutation of a mutable container default (e.g. `config.list << :x`)
              # is visible on every other instance and on the template. A caller that needs a
              # per-instance mutable default should not rely on a mutable `default:` (e.g.
              # `default: []`): assign the value inside a `configure` block, or dup it themselves,
              # so each instance owns its own copy.
              value
            else
              value.deep_dup
            end
          end

          dupped
        end

        # Registers a key-value pair as a setting on an already-compiled node without going
        # through the static `setting` DSL. Useful for dynamic registries (e.g. named clusters)
        # where the keys are not known at class-load time.
        #
        # Unlike `setting`, which is designed to be called at class-definition time, `register`
        # is safe to call at runtime because it:
        #   - appends a pre-compiled Leaf so `deep_dup` and `to_h` include it
        #   - sets `@configs_refs` directly so the reader accessor returns the value immediately
        #   - builds reader/writer accessors via the same `build_accessors` path
        #
        # Raises `ArgumentError` if the name is already registered to prevent silent overwrites.
        #
        # @param name [Symbol, String] setting name
        # @param value [Object] the setting value assigned immediately; also used as the default
        #   when the node is deep-duped and recompiled on a new instance
        # @raise [ArgumentError] when the name is already taken or reserved for the node
        #   internal state
        def register(name, value)
          name = name.to_sym

          prevent_reserved_names!(name)

          raise ArgumentError, "#{name} is already registered" if @configs_refs.key?(name)

          leaf = Leaf.new(name, value, nil, true, false)
          @children << leaf
          build_accessors(leaf)
          config_write(name, value)
        end

        # Converts the settings definitions into end children
        # @note It runs once, after things are compiled, they will not be recompiled again
        def compile
          @children.each do |value|
            # Do not redefine something that was already set during compilation
            # This will allow us to reconfigure things and skip override with defaults
            skippable = @configs_refs.key?(value.node_name) || (value.is_a?(Leaf) && value.compiled?)
            lazy_leaf = value.is_a?(Leaf) && value.lazy?

            # Do not create accessor for leafs that are lazy as they will get a custom method
            # created instead
            build_accessors(value) unless lazy_leaf

            next if skippable

            initialized = if value.is_a?(Leaf)
              value.compiled = true

              if value.constructor && value.lazy?
                false
              elsif value.constructor
                call_constructor(value)
              else
                value.default
              end
            else
              value.compile
              value
            end

            if lazy_leaf && !initialized
              build_dynamic_accessor(value)
            else
              config_write(value.node_name, initialized)
            end
          end

          @compiled = true
        end

        private

        # Defines a lazy evaluated read and writer that will re-evaluate in case value constructor
        # evaluates to `nil` or `false`. This allows us to define dynamic constructors that
        # can react to external conditions to become expected value once this value is available
        #
        # @param value [Leaf]
        def build_dynamic_accessor(value)
          define_singleton_method(value.node_name) do
            existing = @configs_refs.fetch(value.node_name, false)

            return existing unless existing == false

            built = call_constructor(value)

            @configs_refs[value.node_name] = built
          end

          define_singleton_method(:"#{value.node_name}=") do |new_value|
            @configs_refs[value.node_name] = new_value
          end
        end

        # Runs the constructor with or without the default depending on its arity and returns the
        # result
        #
        # @param value [Leaf]
        def call_constructor(value)
          constructor = value.constructor

          if constructor.arity.zero?
            constructor.call
          else
            constructor.call(value.default)
          end
        end

        # Builds regular accessors for value fetching
        #
        # Settings with names that can form valid instance variables get `attr_reader` based
        # readers backed by an ivar mirror of the config value. This is significantly faster
        # than a method with a hash lookup, which matters since settings are read on hot paths
        # across the whole ecosystem. `@configs_refs` remains the canonical store used by
        # `#to_h`, `#compile` and `#register`, with `#config_write` keeping the mirror in sync.
        #
        # @param value [Leaf]
        def build_accessors(value)
          reader_name = value.node_name.to_sym
          reader_respond = respond_to?(reader_name)
          # There is a weird edge-case from 2020, where nodes would not redefine methods that
          # would be defined on Object. Some of users were defining things like `#logger` on
          # object and then we would not redefine it for nodes. This ensures that we only do not
          # redefine our own definitions but we do redefine any user "accidentally" inherited
          # methods
          if reader_respond ? !@local_defs.key?(reader_name) : true
            @local_defs[reader_name] = true

            if ivar_backed?(reader_name)
              singleton_class.attr_reader(reader_name)
            else
              define_singleton_method(reader_name) do
                @configs_refs[reader_name]
              end
            end
          end

          return if respond_to?(:"#{reader_name}=")

          if ivar_backed?(reader_name)
            ivar_name = :"@#{reader_name}"

            define_singleton_method(:"#{reader_name}=") do |new_value|
              instance_variable_set(ivar_name, new_value)
              @configs_refs[reader_name] = new_value
            end
          else
            define_singleton_method(:"#{reader_name}=") do |new_value|
              @configs_refs[reader_name] = new_value
            end
          end
        end

        # Writes a config value to the canonical store and mirrors it into the backing instance
        # variable when the setting uses the fast ivar-backed reader
        #
        # @param name [Symbol, String] setting name
        # @param value [Object] config value assigned to the setting
        def config_write(name, value)
          # Accessors operate on symbolized names, so the store has to be keyed consistently.
          # This also guarantees that a String name matching a reserved internal name is
          # recognized by the `ivar_backed?` guard and cannot corrupt the node internal state
          name = name.to_sym

          @configs_refs[name] = value
          instance_variable_set(:"@#{name}", value) if ivar_backed?(name)
        end

        # @param name [Symbol] setting name
        # @return [Boolean] true if this setting can be backed by an instance variable and use
        #   the fast `attr_reader` based reader
        def ivar_backed?(name)
          !RESERVED_NAMES.key?(name) && IVAR_NAMEABLE_FORMAT.match?(name)
        end

        # Rejects setting names that would collide with the node internal state. Without this,
        # such names would shadow the node own accessors, breaking `#deep_dup` and silently
        # corrupting internals on assignment (e.g. `config.children = value` hitting the node
        # own `attr_writer`)
        #
        # @param name [Symbol] already symbolized setting name
        # @raise [ArgumentError] when the name is reserved
        def prevent_reserved_names!(name)
          return unless RESERVED_NAMES.key?(name)

          raise ArgumentError, "#{name} is a reserved name and cannot be used as a setting name"
        end
      end
    end
  end
end
