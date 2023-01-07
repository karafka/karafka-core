# frozen_string_literal: true

RSpec.describe_current do
  let(:timed) do
    current = described_class

    Class.new do
      extend current
    end
  end

  describe '#monotonic_now' do
    it 'expect to return monotonic in ms' do
      pre = timed.monotonic_now
      sleep(0.5)
      expect(timed.monotonic_now - pre).to be_within(500).of(500)
    end
  end

  describe '#float_now' do
    it 'expect to return float time in ms' do
      pre = timed.float_now
      sleep(0.5)
      expect(timed.float_now - pre).to be_within(500).of(500)
    end
  end
end
