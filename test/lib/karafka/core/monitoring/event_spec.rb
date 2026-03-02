# frozen_string_literal: true

require "test_helper"

describe_current do
  subject(:event) { described_class.new(id, payload) }

  let(:id) { rand.to_s }
  let(:payload) { { rand => rand } }

  it { assert_equal id, event.id }
  it { assert_equal payload, event.payload }

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
