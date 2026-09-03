# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Module building memoized config readers on a target, resolving each attribute path
      # against a supplied config root.
      #
      # An importer lets a class read a few config values under short, local names instead of
      # spelling out the full config path at every call site. Unlike a consumer-specific
      # importer, the root is not hardcoded: it is provided as a callable, so the same class
      # works for any {Configurable}-based config tree (e.g. `Karafka::App.config` or
      # `Karafka::Web.config`).
      #
      # The root is a callable rather than a config object so that it is resolved lazily, on the
      # first read of a given attribute. That matters because importers are typically built while
      # a class body is being loaded, which is usually before the config itself has been set up.
      #
      # Each attribute is memoized per target, so the path is walked only once and every later
      # read is a plain instance variable lookup. Memoization is `||=`-based, so an attribute
      # whose configured value is `nil` or `false` is re-read on each call.
      #
      # @example Import a single nested setting as an instance-level reader
      #   class LagStats
      #     include Karafka::Core::Configurable::Importer.new(
      #       { skew_threshold: %i[ui health lags skew_threshold] },
      #       root: -> { Karafka::Web.config }
      #     )
      #
      #     def skewed?(lag)
      #       lag > skew_threshold
      #     end
      #   end
      #
      # @example Import class-level readers
      #   class Message
      #     extend Karafka::Core::Configurable::Importer.new(
      #       { per_page: %i[ui per_page] },
      #       root: -> { Karafka::Web.config }
      #     )
      #   end
      #
      #   Message.per_page
      #
      # @example Import the whole config root under `#config` (the default)
      #   class Consumer
      #     include Karafka::Core::Configurable::Importer.new(root: -> { Karafka::App.config })
      #   end
      #
      # @note The readers are defined directly on the target, so an attribute name that collides
      #   with an existing method silently replaces it.
      class Importer < Module
        # Default attributes map, exposing the whole config root under `#config`.
        DEFAULT_ATTRIBUTES = { config: %i[itself] }.freeze

        private_constant :DEFAULT_ATTRIBUTES

        # @param attributes [Hash{Symbol => Array<Symbol>}] map defining what to import. The key
        #   is the name the reader will be available under and the value is the path to the
        #   attribute, relative to the root, as an array of message names.
        # @param root [#call] callable returning the config root the paths resolve against. It is
        #   invoked on each memoization miss, not when the importer is built.
        def initialize(attributes = DEFAULT_ATTRIBUTES, root:)
          super()
          @attributes = attributes
          @root = root
        end

        # Defines the readers as instance methods on the target.
        #
        # @param model [Object] object to which we want to add the config fetchers
        # @return [void]
        def included(model)
          super

          define_readers(model, :define_method)
        end

        # Defines the readers as class-level methods on the target.
        #
        # @param model [Object] object to which we want to add the config fetchers on a class
        #   level
        # @return [void]
        def extended(model)
          super

          define_readers(model, :define_singleton_method)
        end

        private

        # Defines one memoized reader per configured attribute on the target.
        #
        # @param model [Object] object the readers are defined on
        # @param definer [Symbol] method used to define them, either `:define_method` for
        #   instance-level readers or `:define_singleton_method` for class-level ones
        # @return [void]
        def define_readers(model, definer)
          root = @root

          @attributes.each do |name, path|
            ivar = :"@#{name}"

            model.public_send(definer, name) do
              instance_variable_get(ivar) || instance_variable_set(
                ivar,
                path.reduce(root.call) { |node, part| node.public_send(part) }
              )
            end
          end
        end
      end
    end
  end
end
