# frozen_string_literal: true

module Karafka
  module Core
    # Namespace related to extension allowing to attach tags to any object.
    # It can be used to assign tags in runtime to objects and use those tags in metrics, reporting
    # and other places.
    #
    # Tags will be converted to strings when they are added
    module Taggable
      # One lock for the first `#tags` call of every object. That call is rare, and a lock per
      # object would need a safe way to create it as well. Kept off the constants, because
      # constants of this module are visible in every class that includes it.
      @tags_lock = Mutex.new

      class << self
        # @return [Mutex] lock guarding the lazy creation of tags
        attr_reader :tags_lock
      end

      # @return [::Karafka::Core::Taggable::Tags] tags object
      def tags
        @tags || taggable_build_tags
      end

      private

      # Do not inline this into `#tags`. A `#synchronize` block there makes every warm `#tags` call
      # about 2.5x slower on JRuby, even when `@tags` is already set. A hand-written `lock` /
      # `ensure unlock` keeps it fast but can leave the lock held when an async exception
      # (`Thread#raise`, `Timeout`) lands between `lock` and `begin`.
      #
      # @return [::Karafka::Core::Taggable::Tags] tags object
      def taggable_build_tags
        Taggable.tags_lock.synchronize { @tags ||= Taggable::Tags.new }
      end
    end
  end
end
