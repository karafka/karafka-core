# frozen_string_literal: true

describe_current do
  before do
    @id = rand.to_s
    @payload = { rand => rand }
    @event = Karafka::Core::Monitoring::Event.new(@id, @payload)
  end

  it "expect to expose id" do
    assert_equal @id, @event.id
  end

  it "expect to expose payload" do
    assert_equal @payload, @event.payload
  end

  describe "#[]" do
    describe "when key is present" do
      it "expect to return it" do
        event = Karafka::Core::Monitoring::Event.new(@id, { test: 1 })

        assert_equal 1, event[:test]
      end
    end

    describe "when key is missing" do
      it "expect to raise KeyError" do
        assert_raises(KeyError) { @event[:test] }
      end
    end
  end
end
