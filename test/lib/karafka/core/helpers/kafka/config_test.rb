# frozen_string_literal: true

describe_current do
  describe "#enabled?" do
    [true, "true"].each do |value|
      it "expect to be true for #{value.inspect}" do
        assert described_class.enabled?(value)
      end
    end

    [false, "false", nil, "TRUE", "1", 1, "t", ""].each do |value|
      it "expect to be false for #{value.inspect}" do
        refute described_class.enabled?(value)
      end
    end
  end
end
