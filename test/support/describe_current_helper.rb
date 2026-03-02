# frozen_string_literal: true

# Port of Karafka::Core::Helpers::RSpecLocator for minitest/spec
# Provides `describe_current` that auto-discovers the class under test from file path,
# `described_class` and `subject` DSL methods.

require "karafka/core/helpers/minitest_locator"

extend Karafka::Core::Helpers::MinitestLocator.new(
  File.expand_path("../test_helper.rb", __dir__)
)

# Provide `described_class` for minitest/spec — walks the desc hierarchy to find a Class/Module
module MinitestDescribedClass
  def described_class
    # Walk up the describe hierarchy to find the Class/Module
    klass = self.class
    while klass
      return klass.desc if klass.respond_to?(:desc) && klass.desc.is_a?(Module)

      klass = klass.superclass
    end
    nil
  end
end

Minitest::Spec.include MinitestDescribedClass

# Provide `subject` DSL for minitest/spec
module MinitestSubjectDSL
  def subject(name = nil, &block)
    if name
      let(name, &block)
      define_method(:subject) { send(name) }
    else
      let(:subject, &block)
    end
  end
end

Minitest::Spec.extend MinitestSubjectDSL
