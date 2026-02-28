# frozen_string_literal: true

class KarafkaCoreMonitoringMonitorNoNamespaceTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
    @collected_data = []

    collected = @collected_data
    @monitor.subscribe("test") do |event|
      collected << event
    end

    @monitor.instrument("test") { 1 }
  end

  def test_collected_data_size
    assert_equal 1, @collected_data.size
  end

  def test_collected_event_id
    assert_equal "test", @collected_data.first.id
  end

  def test_listeners_keys_include_event
    assert_includes @monitor.listeners.keys, "test"
  end

  def test_listeners_value_is_array
    assert_kind_of Array, @monitor.listeners["test"]
  end
end

class KarafkaCoreMonitoringMonitorWithNamespaceTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, "namespace")
    @collected_data = []

    collected = @collected_data
    @monitor.subscribe("test.namespace") do |event|
      collected << event
    end

    @monitor.instrument("test") { 1 }
  end

  def test_collected_data_size
    assert_equal 1, @collected_data.size
  end

  def test_collected_event_id
    assert_equal "test.namespace", @collected_data.first.id
  end

  def test_listeners_keys_include_event
    assert_includes @monitor.listeners.keys, "test"
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeNoNamespaceTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
    @collected_data = []
    @block_listener = proc { |event| @collected_data << event }
    @monitor.subscribe("test", &@block_listener)
  end

  def test_unsubscribe_removes_listener_from_event
    @monitor.unsubscribe(@block_listener)
    @monitor.instrument("test") { 1 }

    assert_empty @collected_data
  end

  def test_unsubscribe_removes_listener_from_listeners_hash
    assert_includes @monitor.listeners["test"], @block_listener
    @monitor.unsubscribe(@block_listener)

    refute_includes @monitor.listeners["test"], @block_listener
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeWithNamespaceTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, "namespace")
    @collected_data = []
    @block_listener = proc { |event| @collected_data << event }
    @monitor.subscribe("test.namespace", &@block_listener)
  end

  def test_unsubscribe_removes_listener_from_namespaced_event
    @monitor.unsubscribe(@block_listener)
    @monitor.instrument("test") { 1 }

    assert_empty @collected_data
  end

  def test_unsubscribe_removes_listener_from_listeners_hash
    assert_includes @monitor.listeners["test.namespace"], @block_listener
    @monitor.unsubscribe(@block_listener)

    refute_includes @monitor.listeners["test.namespace"], @block_listener
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeObjectListenerTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)

    listener_class = Class.new do
      attr_reader :accu

      def initialize
        @accu = []
      end

      def on_test(event)
        @accu << event
      end
    end

    @listener = listener_class.new
    @monitor.subscribe(@listener)
  end

  def test_unsubscribe_removes_object_listener
    @monitor.unsubscribe(@listener)
    @monitor.instrument("test") { 1 }

    assert_empty @listener.accu
  end

  def test_unsubscribe_removes_from_listeners_hash
    assert_includes @monitor.listeners["test"], @listener
    @monitor.unsubscribe(@listener)

    refute_includes @monitor.listeners["test"], @listener
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeNeverSubscribedTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
  end

  def test_unsubscribe_does_not_raise
    unsubscribed_listener = proc { |event| event }
    @monitor.unsubscribe(unsubscribed_listener)
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeMultipleListenersTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)

    @first_collected = []
    @second_collected = []

    @first_listener = proc { |event| @first_collected << event }
    @second_listener = proc { |event| @second_collected << event }

    @monitor.subscribe("test", &@first_listener)
    @monitor.subscribe("test", &@second_listener)
    @first_listener_added = @monitor.listeners["test"][0]
  end

  def test_only_removes_specified_listener
    @monitor.unsubscribe(@first_listener_added)
    @monitor.instrument("test") { 1 }

    assert_empty @first_collected
    refute_empty @second_collected
  end

  def test_keeps_other_listener_in_hash
    assert_includes @monitor.listeners["test"], @first_listener
    assert_includes @monitor.listeners["test"], @second_listener
    @monitor.unsubscribe(@first_listener_added)

    assert_same false, @monitor.listeners["test"].include?(@first_listener_added)
    assert_includes @monitor.listeners["test"], @second_listener
  end
end

class KarafkaCoreMonitoringMonitorUnsubscribeMultiEventListenerTest < Minitest::Test
  def setup
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
    @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)

    listener_class = Class.new do
      attr_reader :accu

      def initialize
        @accu = []
      end

      def on_test(event)
        @accu << event
      end

      def on_test_namespace(event)
        @accu << event
      end
    end

    @multi_event_listener = listener_class.new
    @monitor.subscribe(@multi_event_listener)
  end

  def test_removes_listener_from_all_events
    @monitor.unsubscribe(@multi_event_listener)
    @monitor.instrument("test") { 1 }
    @monitor.instrument("test.namespace") { 1 }

    assert_empty @multi_event_listener.accu
  end
end
