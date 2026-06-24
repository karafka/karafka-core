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

  describe "concurrency safety" do
    # Regression: a callback added concurrently while #call is taking its snapshot of the
    # registered callbacks must not be permanently lost. A previous optimization cached the
    # values snapshot and invalidated it on add/delete; under interleaving, #call could write
    # a stale snapshot back over a concurrent invalidation, so a newly added callback would
    # never fire afterwards (and a deleted one would keep firing forever). We force the exact
    # interleaving deterministically with a Hash whose #values mutates the manager right after
    # the snapshot is read.
    it "does not permanently drop a callback added while a call snapshots the callbacks" do
      racy = Class.new(Hash) do
        attr_accessor :after_values

        def values
          snapshot = super
          after_values&.call
          snapshot
        end
      end.new

      manager.instance_variable_set(:@callbacks, racy)
      manager.add("a", -> { changed << :a })

      # Simulate another thread adding a callback in the window between the snapshot read
      # and any cache write-back inside #call. Runs once.
      racy.after_values = lambda do
        racy.after_values = nil
        manager.add("b", -> { changed << :b })
      end

      manager.call # snapshots [a], then "b" is added in the race window
      changed.clear
      manager.call # "b" must fire now; if it was lost to a stale cache it never will

      assert_includes changed, :b
    end
  end
end
