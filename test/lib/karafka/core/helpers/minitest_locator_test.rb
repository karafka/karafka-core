# frozen_string_literal: true

describe_current do
  let(:locator) { Karafka::Core::Helpers::MinitestLocator.new("/tmp/test_helper.rb") }

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
