# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/core/version'

Gem::Specification.new do |spec|
  spec.name        = 'karafka-core'
  spec.version     = ::Karafka::Core::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Maciej Mensfeld']
  spec.email       = %w[contact@karafka.io]
  spec.homepage    = 'https://karafka.io'
  spec.summary     = 'Karafka ecosystem core modules'
  spec.description = 'A toolset of small support modules used throughout the Karafka ecosystem'
  spec.licenses    = %w[MIT]

  spec.add_dependency 'karafka-rdkafka', '>= 0.19.2', '< 0.21.0'
  spec.add_dependency 'logger', '>= 1.6.0'

  spec.required_ruby_version = '>= 3.1.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.require_paths = %w[lib]

  spec.metadata = {
    'funding_uri' => 'https://karafka.io/#become-pro',
    'homepage_uri' => 'https://karafka.io',
    'changelog_uri' => 'https://karafka.io/docs/Changelog-Karafka-Core',
    'bug_tracker_uri' => 'https://github.com/karafka/karafka-core/issues',
    'source_code_uri' => 'https://github.com/karafka/karafka-core',
    'documentation_uri' => 'https://karafka.io/docs',
    'rubygems_mfa_required' => 'true'
  }
end
