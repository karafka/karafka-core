# frozen_string_literal: true

require "karafka/core/helpers/rspec_locator"

describe Karafka::Core::Helpers::RSpecLocator do
  let(:locator) { Karafka::Core::Helpers::RSpecLocator.new("/tmp/spec_helper.rb") }

  describe "#describe_current" do
    let(:specs_root) { Dir.mktmpdir }
    let(:spec_file) { File.join(specs_root, "lib/karafka/core/monitoring/statistics_decorator_spec.rb") }
    let(:rspec) do
      Module.new do
        class << self
          attr_reader :described

          def describe(described, &)
            @described = described
          end
        end
      end
    end

    before do
      rspec.extend(
        Karafka::Core::Helpers::RSpecLocator.new(
          File.join(specs_root, "spec_helper.rb"),
          "Decorator" => "Decorator"
        )
      )

      FileUtils.mkdir_p(File.dirname(spec_file))
      File.write(spec_file, "RSPEC_LOCATOR_TEST_TARGET.describe_current {}\n")
    end

    after { FileUtils.rm_rf(specs_root) }

    it "expect to describe the class matching the spec file path" do
      Object.const_set(:RSPEC_LOCATOR_TEST_TARGET, rspec)
      load(spec_file)

      assert_same Karafka::Core::Monitoring::StatisticsDecorator, rspec.described
    ensure
      Object.send(:remove_const, :RSPEC_LOCATOR_TEST_TARGET)
    end
  end

  describe "#custom_constantize" do
    it "expect to resolve an existing constant" do
      assert_same Karafka::Core, locator.send(:custom_constantize, "Karafka::Core")
    end

    context "when a segment is not a valid constant name" do
      let(:error) { assert_raises(NameError) { locator.send(:custom_constantize, "Karafka::bad") } }

      it "expect to use the constant name as the message" do
        assert_equal "Karafka::bad", error.message
      end

      it "expect to keep the invalid segment error as the cause" do
        assert_equal "bad", error.cause.message
      end
    end

    context "when the constant does not exist" do
      let(:error) do
        assert_raises(NameError) { locator.send(:custom_constantize, "Karafka::Missing") }
      end

      it "expect to use the constant name as the message" do
        assert_equal "Karafka::Missing", error.message
      end

      it "expect to keep the lookup error as the cause" do
        assert_kind_of NameError, error.cause
        assert_includes error.cause.message, "Karafka::Missing"
      end
    end
  end
end
