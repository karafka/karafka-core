# frozen_string_literal: true

describe_current do
  before do
    @manager = Karafka::Core::Instrumentation::CallbacksManager.new
    @id = SecureRandom.uuid
    @changed = []
  end

  describe "#call" do
    describe "when there are no callbacks added" do
      it "expect not to raise" do
        @manager.call
      end
    end

    describe "when there are callbacks added" do
      it "expect to run each of them and pass the args" do
        start = [rand, rand, rand]
        @manager.add("1", ->(val1, _, _) { @changed << (val1 + 1) })
        @manager.add("2", ->(_, val2, _) { @changed << (val2 + 2) })
        @manager.add("3", ->(_, _, val3) { @changed << (val3 + 3) })

        @manager.call(*start)

        assert_equal [start[0] + 1, start[1] + 2, start[2] + 3], @changed
      end
    end
  end

  describe "#add" do
    it "expect after adding to be used" do
      @manager.add(@id, -> { @changed << true })
      @manager.call

      assert_equal [true], @changed
    end

    describe "when we are adding a callback but at the same time, we call callbacks" do
      before do
        @callable = lambda do
          @changed << true
          sleep(10)
        end

        @manager.add(@id, @callable)
        Thread.new { @manager.call }
        sleep(0.001) while @changed.empty?
      end

      it "expect not to raise" do
        added_id = SecureRandom.uuid
        @manager.add(added_id, @callable)
      end

      it "expect to register the new callback" do
        @manager.delete(@id)
        added_id = SecureRandom.uuid
        @manager.add(added_id, -> { @changed << true })

        @manager.call

        assert_equal [true, true], @changed
      end
    end
  end

  describe "#delete" do
    it "expect after removal not to be used" do
      @manager.add(@id, -> { @changed << true })
      @manager.delete(@id)
      @manager.call

      assert_empty @changed
    end
  end
end
