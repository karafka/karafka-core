# frozen_string_literal: true

class KarafkaCoreCallbacksManagerTest < Minitest::Test
  def setup
    @manager = Karafka::Core::Instrumentation::CallbacksManager.new
    @id = SecureRandom.uuid
    @changed = []
  end

  def test_call_with_no_callbacks
    @manager.call
  end

  def test_call_with_callbacks_passes_args
    start = [rand, rand, rand]
    @manager.add("1", ->(val1, _, _) { @changed << (val1 + 1) })
    @manager.add("2", ->(_, val2, _) { @changed << (val2 + 2) })
    @manager.add("3", ->(_, _, val3) { @changed << (val3 + 3) })

    @manager.call(*start)
    assert_equal [start[0] + 1, start[1] + 2, start[2] + 3], @changed
  end

  def test_add_makes_callback_available
    @manager.add(@id, -> { @changed << true })
    @manager.call
    assert_equal [true], @changed
  end

  def test_add_during_concurrent_call
    callable = lambda do
      @changed << true
      sleep(10)
    end

    @manager.add(@id, callable)
    Thread.new { @manager.call }
    sleep(0.001) while @changed.empty?

    added_id = SecureRandom.uuid
    @manager.add(added_id, callable)
  end

  def test_add_during_concurrent_call_registers_new_callback
    callable = lambda do
      @changed << true
      sleep(10)
    end

    @manager.add(@id, callable)
    Thread.new { @manager.call }
    sleep(0.001) while @changed.empty?

    added_id = SecureRandom.uuid
    @manager.delete(@id)
    @manager.add(added_id, -> { @changed << true })

    @manager.call

    assert_equal [true, true], @changed
  end

  def test_delete_removes_callback
    @manager.add(@id, -> { @changed << true })
    @manager.delete(@id)
    @manager.call
    assert_empty @changed
  end
end
