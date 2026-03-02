# frozen_string_literal: true

# Port of Karafka::Core::Helpers::RSpecLocator for minitest/spec
# Provides `describe_current` that auto-discovers the class under test from file path,
# `described_class` and `subject` DSL methods.

TESTS_ROOT_DIR = File.expand_path("..", __dir__)

# Top-level method: auto-discovers the class from the caller file path and opens a describe block
def describe_current(&block)
  klass = caller(1..1)
    .first
    .split(":")
    .first
    .gsub(TESTS_ROOT_DIR, "")
    .gsub("_test.rb", "")
    .split("/")
    .delete_if(&:empty?)
    .itself[1..]
    .join("/")
    .then { |path| custom_camelize(path) }
    .then { |class_name| custom_constantize(class_name) }

  describe(klass, &block)
end

# Custom implementation of camelize without ActiveSupport
def custom_camelize(string)
  string = string.gsub("/", "::")

  string.gsub(/(?:^|_|::)([a-z])/) do |match|
    if match.include?("::")
      "::#{match[-1].upcase}"
    else
      match[-1].upcase
    end
  end
end

# Custom implementation of constantize without ActiveSupport
def custom_constantize(string)
  names = string.split("::")
  constant = Object
  regexp = /^[A-Z][a-zA-Z0-9_]*$/

  names.each do |name|
    raise NameError, "#{name} is not a valid constant name!" unless name.match?(regexp)

    constant = constant.const_get(name)
  end

  constant
rescue NameError => e
  raise NameError, "Uninitialized constant #{string}: #{e.message}"
end

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
