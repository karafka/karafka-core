# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'karafka/core/version'

Gem::Specification.new do |spec|
  spec.name        = 'karafka-core'
  spec.version     = ::Karafka::Core::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Maciej Mensfeld']
  spec.email       = %w[maciej@mensfeld.pl]
  spec.homepage    = 'https://karafka.io'
  spec.summary     = 'Karafka ecosystem core modules'
  spec.description = 'A toolset of small support modules used throughout the Karafka ecosystem'
  spec.licenses    = %w[MIT]
  spec.add_dependency 'concurrent-ruby', '>= 1.1'

  spec.required_ruby_version = '>= 2.6.0'

  if $PROGRAM_NAME.end_with?('gem')
    spec.signing_key = File.expand_path('~/.ssh/gem-private_key.pem')
  end

  spec.cert_chain    = %w[certs/mensfeld.pem]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.require_paths = %w[lib]

  spec.metadata = {
    'source_code_uri' => 'https://github.com/karafka/karafka-core',
    'rubygems_mfa_required' => 'true'
  }
end
