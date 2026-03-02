# frozen_string_literal: true

describe_current do
  subject(:manager) { described_class.new }

  let(:id) { SecureRandom.uuid }
  let(:changed) { [] }

  describe "#call" do
    context "when there are no callbacks added" do
      it { manager.call }
    end

    context "when there are callbacks added" do
      let(:changed) { [] }
      let(:start) { [rand, rand, rand] }

      before do
        manager.add("1", ->(val1, _, _) { changed << (val1 + 1) })
        manager.add("2", ->(_, val2, _) { changed << (val2 + 2) })
        manager.add("3", ->(_, _, val3) { changed << (val3 + 3) })
      end

      it "expect to run each of them and pass the args" do
        manager.call(*start)

        assert_equal [start[0] + 1, start[1] + 2, start[2] + 3], changed
      end
    end
  end

  describe "#add" do
    it "expect after adding to be used" do
      manager.add(id, -> { changed << true })
      manager.call

      assert_equal [true], changed
    end

    context "when we are adding a callback but at the same time, we call callbacks" do
      let(:added_id) { SecureRandom.uuid }
      let(:callable) do
        lambda do
          changed << true
          sleep(10)
        end
      end

      before do
        # This will simulate a long running callback when manager is called, so when we add new one
        # The previous one is still running in a thread
        manager.add(id, callable)
        Thread.new { manager.call }
        # This makes sure, that we wait until the thread kicks in
        sleep(0.001) while changed.empty?
      end

      it { manager.add(added_id, callable) }

      it "expect to register the new callback" do
        manager.delete(id)
        manager.add(added_id, -> { changed << true })

        manager.call

        assert_equal [true, true], changed
      end
    end
  end

  describe "#delete" do
    before { manager.add(id, -> { changed << true }) }

    it "expect after removal not to be used" do
      manager.delete(id)
      manager.call

      assert_empty changed
    end
  end
end
