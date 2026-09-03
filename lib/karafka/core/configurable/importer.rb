# frozen_string_literal: true

module Karafka
  module Core
    module Configurable
      # Base class for config importers.
      #
      # An importer builds memoized config readers on a target, so a class can read a few config
      # values under short, local names instead of spelling out the full config path at every
      # call site.
      #
      # The config root is not hardcoded and is not passed per use site: it is defined once, by
      # overriding {root} in a subclass. Each consumer therefore ships one importer subclass
      # pointing at its own config tree (e.g. `Karafka::App.config` or `Karafka::Web.config`),
      # and every use site only names the attributes it wants.
      #
      # {root} is a method rather than a stored config object, so it is resolved lazily, on the
      # first read of a given attribute. That matters because importers are typically built while
      # a class body is being loaded, which is usually before the config itself has been set up.
      #
      # Each attribute is memoized per target, so the path is walked only once and every later
      # read is a plain instance variable lookup. Memoization is `||=`-based, so an attribute
      # whose configured value is `nil` or `false` is re-read on each call.
      #
      # @example Define the importer once, with the root
      #   module Karafka
      #     module Web
      #       module Helpers
      #         class ConfigImporter < Karafka::Core::Configurable::Importer
      #           class << self
      #             def root
      #               Karafka::Web.config
      #             end
      #           end
      #         end
      #       end
      #     end
      #   end
      #
      # @example Import instance-level readers
      #   class LagStats
      #     include Karafka::Web::Helpers::ConfigImporter.new(
      #       skew_threshold: %i[ui health lags skew_threshold]
      #     )
      #
      #     def skewed?(lag)
      #       lag > skew_threshold
      #     end
      #   end
      #
      # @example Import class-level readers
      #   class Message
      #     extend Karafka::Web::Helpers::ConfigImporter.new(per_page: %i[ui per_page])
      #   end
      #
      #   Message.per_page
      #
      # @example Import the whole config root under `#config` (the default)
      #   class Consumer
      #     include Karafka::Web::Helpers::ConfigImporter.new
      #   end
      #
      # @note The base class defines no root of its own; it is not useful directly and is expected
      #   to be subclassed. Reading an attribute off an importer whose class defines no {root}
      #   raises `NotImplementedError`.
      #
      # @note The readers are defined directly on the target, so an attribute name that collides
      #   with an existing method silently replaces it.
      class Importer < Module
        # Default attributes map, exposing the whole config root under `#config`.
        DEFAULT_ATTRIBUTES = { config: %i[itself] }.freeze

        private_constant :DEFAULT_ATTRIBUTES

        class << self
          # @return [Object] config root the attribute paths are resolved against. Override in
          #   subclasses; the base class defines none. Called on each memoization miss rather
          #   than when the importer is built, so it may safely reference a config that does not
          #   exist yet at load time.
          # @raise [NotImplementedError] when called on a class that does not define a root
          def root
            raise(
              NotImplementedError,
              "Define .root in a Karafka::Core::Configurable::Importer subclass"
            )
          end
        end

        # @param attributes [Hash{Symbol => Array<Symbol>}] map defining what to import. The key
        #   is the name the reader will be available under and the value is the path to the
        #   attribute, relative to the root, as an array of message names.
        def initialize(attributes = DEFAULT_ATTRIBUTES)
          super()
          @attributes = attributes
        end

        # @return [Object] config root this importer resolves against, as defined by its class
        def root
          self.class.root
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
          importer = self

          @attributes.each do |name, path|
            ivar = :"@#{name}"

            model.public_send(definer, name) do
              instance_variable_get(ivar) || instance_variable_set(
                ivar,
                path.reduce(importer.root) { |node, part| node.public_send(part) }
              )
            end
          end
        end
      end
    end
  end
end
