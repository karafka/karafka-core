# frozen_string_literal: true

class KarafkaCoreHelpersTimeTest < Minitest::Test
  def setup
    @timed = Class.new { extend Karafka::Core::Helpers::Time }
  end

  def test_monotonic_now_returns_monotonic_in_ms
    pre = @timed.monotonic_now
    sleep(0.5)

    assert_in_delta 500, @timed.monotonic_now - pre, 500
  end

  def test_float_now_returns_float_time_in_ms
    pre = @timed.float_now
    sleep(0.5)

    assert_in_delta 500, @timed.float_now - pre, 500
  end
end
