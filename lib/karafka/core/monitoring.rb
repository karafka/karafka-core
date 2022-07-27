# frozen_string_literal: true

# Main module namespace
module Karafka
  module Core
    # Monitoring for Karafka and WaterDrop
    # It allows us to have a layer that can work with `dry-monitor` as well as
    # `ActiveSupport::Notifications` or standalone depending on the case. Thanks to that we do not
    # have to rely on third party tools that could break.
    module Monitoring
    end
  end
end
