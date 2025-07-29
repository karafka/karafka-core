# frozen_string_literal: true

Warning[:performance] = true
Warning[:deprecated] = true
$VERBOSE = true

require 'warning'

Warning.process do |warning|
  next unless warning.include?(Dir.pwd)

  raise "Warning in your code: #{warning}"
end

ENV['KARAFKA_ENV'] = 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

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
  add_filter '/vendor/'
  add_filter '/gems/'
  add_filter '/.bundle/'
  add_filter '/doc/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/patches/'
  merge_timeout 600
end

SimpleCov.minimum_coverage(98.8)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"]
  .sort
  .each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
end

require 'karafka-core'
require 'karafka/core/helpers/rspec_locator'
RSpec.extend Karafka::Core::Helpers::RSpecLocator.new(__FILE__)
