# frozen_string_literal: true

describe_current do
  let(:root) { Dir.mktmpdir }
  let(:target) do
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
    target.extend(Karafka::Core::Helpers::MinitestLocator.new(File.join(root, "test_helper.rb")))
  end

  after { FileUtils.rm_rf(root) }

  # Loads a generated file at the given path under the root that calls `describe_current`
  def describe_from(relative_path)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "TARGET.describe_current {}\n")

    # The loaded file resolves `TARGET` in this wrapping module
    load(path, Module.new.tap { |wrap| wrap.const_set(:TARGET, target) })
  end

  describe "#describe_current" do
    it "expect to describe the class matching the file path" do
      describe_from("lib/karafka/core/monitoring/statistics_decorator_test.rb")

      assert_same Karafka::Core::Monitoring::StatisticsDecorator, target.described
    end

    context "when a path segment is not a valid constant name" do
      let(:error) do
        assert_raises(NameError) { describe_from("lib/karafka/1invalid/thing_test.rb") }
      end

      it "expect to use the constant name as the message" do
        assert_equal "Karafka::1invalid::Thing", error.message
      end

      it "expect to keep the invalid segment error as the cause" do
        assert_equal "1invalid", error.cause.message
      end
    end

    context "when the constant does not exist" do
      let(:error) { assert_raises(NameError) { describe_from("lib/karafka/missing_test.rb") } }

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
