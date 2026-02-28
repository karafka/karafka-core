# frozen_string_literal: true

class KarafkaCoreMonitoringEventTest < Minitest::Test
  def setup
    @id = rand.to_s
    @payload = { rand => rand }
    @event = Karafka::Core::Monitoring::Event.new(@id, @payload)
  end

  def test_id
    assert_equal @id, @event.id
  end

  def test_payload
    assert_equal @payload, @event.payload
  end

  def test_bracket_returns_value_when_key_present
    event = Karafka::Core::Monitoring::Event.new(@id, { test: 1 })
    assert_equal 1, event[:test]
  end

  def test_bracket_raises_key_error_when_key_missing
    assert_raises(KeyError) { @event[:test] }
  end
end
