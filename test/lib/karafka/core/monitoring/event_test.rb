# frozen_string_literal: true

describe_current do
  subject(:event) { described_class.new(id, payload) }

  let(:id) { rand.to_s }
  let(:payload) { { rand => rand } }

  it { assert_equal id, event.id }
  it { assert_equal payload, event.payload }

  describe "when time is provided" do
    subject(:timed_event) { described_class.new(id, payload, execution_time) }

    let(:execution_time) { rand }

    context "when payload is empty" do
      let(:payload) { {} }

      it "expect to return only time in payload" do
        assert_equal({ time: execution_time }, timed_event.payload)
      end
    end

    context "when payload is non-empty" do
      let(:payload) { { key: "value" } }

      it "expect to merge time into payload" do
        assert_equal({ key: "value", time: execution_time }, timed_event.payload)
      end
    end

    describe "#[] with time" do
      let(:payload) { { key: "value" } }

      it "expect to return time directly via #[] without triggering payload construction" do
        assert_equal execution_time, timed_event[:time]
        # We intentionally inspect the internal @payload ivar to ensure that #[] returns time
        # without triggering the lazy payload memoization as a side effect.
        assert_nil timed_event.instance_variable_get(:@payload)
      end

      it "expect to still access raw payload keys" do
        assert_equal "value", timed_event[:key]
      end
    end
  end

  describe "#[]" do
    context "when key is present" do
      let(:payload) { { test: 1 } }

      it "expect to return it" do
        assert_equal 1, event[:test]
      end
    end

    context "when key is missing" do
      it { assert_raises(KeyError) { event[:test] } }
    end
  end
end
