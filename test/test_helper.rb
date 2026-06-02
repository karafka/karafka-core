# frozen_string_literal: true

Warning[:deprecated] = true
$VERBOSE = true

require "warning"

# Enable all opt-in warning categories. Warning.categories is available
# since Ruby 3.4; on older Rubies this is a no-op.
if Warning.respond_to?(:categories)
  (Warning.categories - %i[deprecated experimental]).each { |cat| Warning[cat] = true }
end

Warning.process do |warning|
  next unless warning.include?(Dir.pwd)

  raise "Warning in your code: #{warning}"
end

ENV["KARAFKA_ENV"] = "test"
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

%w[
  byebug
  simplecov
  tempfile
  securerandom
].each do |lib|
  require lib
end

# Don't include unnecessary stuff into rcov
SimpleCov.start do
  add_filter "/vendor/"
  add_filter "/gems/"
  add_filter "/.bundle/"
  add_filter "/doc/"
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/patches/"
  merge_timeout 600
end

SimpleCov.minimum_coverage(98.8)

require "minitest/autorun"
require "minitest/spec"

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"]
  .each { |f| require f }

require "karafka-core"

# Allow `context` as an alias for `describe` in minitest/spec
Minitest::Spec.class_eval do
  class << self
    alias_method :context, :describe
  end
end
