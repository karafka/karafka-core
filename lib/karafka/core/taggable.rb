# frozen_string_literal: true

module Karafka
  module Core
    # Namespace related to extension allowing to attach tags to any object.
    # It can be used to assign tags in runtime to objects and use those tags in metrics, reporting
    # and other places.
    #
    # Tags will be converted to strings when they are added
    module Taggable
      # @return [::Karafka::Core::Taggable::Tags] tags object
      def tags
        @tags ||= Taggable::Tags.new
      end
    end
  end
end
