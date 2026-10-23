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
        return @tags if @tags

        # lock/unlock instead of #synchronize: a block in this method makes every call slower on
        # JRuby, also when @tags is already set
        lock = Taggable.tags_lock
        lock.lock
        begin
          @tags ||= Taggable::Tags.new
        ensure
          lock.unlock
        end
      end
    end
  end
end
