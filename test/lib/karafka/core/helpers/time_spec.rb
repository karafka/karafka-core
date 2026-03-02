# frozen_string_literal: true

require "test_helper"

describe_current do
  let(:timed) do
    current = described_class

    Class.new do
      extend current
    end
  end

  describe "#monotonic_now" do
    it "expect to return monotonic in ms" do
      pre = timed.monotonic_now
      sleep(0.5)

      assert_in_delta 500, timed.monotonic_now - pre, 500
    end
  end

  describe "#float_now" do
    it "expect to return float time in ms" do
      pre = timed.float_now
      sleep(0.5)

      assert_in_delta 500, timed.float_now - pre, 500
    end
  end
end
