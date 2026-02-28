# frozen_string_literal: true

class KarafkaCoreMonitoringNotificationsInstrumentTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_instrument_returns_block_value
    result = rand
    instrumentation = @notifications.instrument(@event_name, call: self, error: StandardError) { result }

    assert_equal result, instrumentation
  end

  def test_instrument_unregistered_event_raises
    assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
      @notifications.instrument("na")
    end
  end
end

class KarafkaCoreMonitoringNotificationsSubscribeTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_subscribe_to_unsupported_event_raises
    assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
      @notifications.subscribe("na") { |_event| nil }
    end
  end

  def test_subscribe_to_supported_event
    @notifications.subscribe(@event_name) { |_event| nil }
  end

  def test_subscribe_with_object_listener
    listener = Class.new do
      def on_message_produced_async(_event)
        true
      end
    end

    @notifications.subscribe(listener.new)
  end
end

class KarafkaCoreMonitoringNotificationsUnsubscribeBlockTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
    @tracked = []
    @block_listener = proc { |event| @tracked << event }
    @notifications.subscribe(@event_name, &@block_listener)
  end

  def test_unsubscribe_removes_block_from_event
    @notifications.unsubscribe(@block_listener)
    @notifications.instrument(@event_name)

    assert_empty @tracked
  end

  def test_unsubscribe_removes_block_from_all_events
    second_event = "message.consumed"
    @notifications.register_event(second_event)
    @notifications.subscribe(second_event, &@block_listener)

    @notifications.unsubscribe(@block_listener)
    @notifications.instrument(@event_name)
    @notifications.instrument(second_event)

    assert_empty @tracked
  end
end

class KarafkaCoreMonitoringNotificationsUnsubscribeObjectTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)

    listener_class = Class.new do
      attr_reader :accu

      def initialize
        @accu = []
      end

      def on_message_produced_async(event)
        @accu << event
      end

      def on_message_consumed(event)
        @accu << event
      end
    end

    @listener = listener_class.new
    @notifications.subscribe(@listener)
  end

  def test_unsubscribe_removes_object_listener
    @notifications.unsubscribe(@listener)
    @notifications.instrument(@event_name)

    assert_empty @listener.accu
  end

  def test_unsubscribe_removes_from_all_events
    second_event = "message.consumed"
    @notifications.register_event(second_event)
    @notifications.subscribe(@listener)

    @notifications.unsubscribe(@listener)
    @notifications.instrument(@event_name)
    @notifications.instrument(second_event)

    assert_empty @listener.accu
  end
end

class KarafkaCoreMonitoringNotificationsUnsubscribeNeverSubscribedTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_does_not_raise
    unsubscribed = Class.new do
      def on_message_produced_async(_event)
        true
      end
    end.new

    @notifications.unsubscribe(unsubscribed)
  end
end

class KarafkaCoreMonitoringNotificationsUnsubscribeMultipleTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
    @tracked_first = []
    @tracked_second = []
    @first_listener = proc { |event| @tracked_first << event }
    @second_listener = proc { |event| @tracked_second << event }
    @notifications.subscribe(@event_name, &@first_listener)
    @notifications.subscribe(@event_name, &@second_listener)
  end

  def test_only_removes_specified_listener
    @notifications.unsubscribe(@first_listener)
    @notifications.instrument(@event_name)

    assert_empty @tracked_first
    refute_empty @tracked_second
  end
end

class KarafkaCoreMonitoringNotificationsAvailableEventsTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_available_events
    assert_equal [@event_name], @notifications.available_events
  end
end

class KarafkaCoreMonitoringNotificationsClearTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_clear_all_removes_subscriptions
    @notifications.subscribe(@event_name) { raise }
    @notifications.clear
    @notifications.instrument(@event_name)
  end

  def test_clear_one_event_only
    instrumented = []
    @notifications.register_event("some-other-event")
    @notifications.subscribe(@event_name) { instrumented.push(1) }
    @notifications.subscribe("some-other-event") { instrumented.push(2) }

    @notifications.clear("some-other-event")
    @notifications.instrument(@event_name)
    @notifications.instrument("some-other-event")

    assert_equal [1], instrumented
  end

  def test_clear_nonexistent_event_raises
    assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
      @notifications.clear("some-nonexistent-event")
    end
  end
end

class KarafkaCoreMonitoringNotificationsFlowTest < Minitest::Test
  def setup
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  def test_subscribe_with_proc_listener
    tracked = []
    @notifications.subscribe(@event_name) { |event| tracked << event }
    @notifications.instrument(@event_name)

    assert_equal @event_name, tracked[0].id
  end

  def test_subscribe_with_class_listener
    listener_class = Class.new do
      attr_reader :accu

      def initialize
        @accu = []
      end

      def on_message_produced_async(event)
        @accu << event
      end
    end

    listener = listener_class.new
    @notifications.subscribe(listener)
    @notifications.instrument(@event_name)

    assert_equal @event_name, listener.accu[0].id
  end
end
