# frozen_string_literal: true

describe_current do
  before do
    @notifications_bus = Karafka::Core::Monitoring::Notifications.new
    @notifications_bus.register_event("test")
    @notifications_bus.register_event("test.namespace")
  end

  describe "when we do not use any namespace" do
    before do
      @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
      @collected_data = []

      collected = @collected_data
      @monitor.subscribe("test") do |event|
        collected << event
      end

      @monitor.instrument("test") { 1 }
    end

    it { assert_equal 1, @collected_data.size }
    it { assert_equal "test", @collected_data.first.id }
    it { assert_includes @monitor.listeners.keys, "test" }
    it { assert_kind_of Array, @monitor.listeners["test"] }
  end

  describe "when we do use a namespace" do
    before do
      @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, "namespace")
      @collected_data = []

      collected = @collected_data
      @monitor.subscribe("test.namespace") do |event|
        collected << event
      end

      @monitor.instrument("test") { 1 }
    end

    it { assert_equal 1, @collected_data.size }
    it { assert_equal "test.namespace", @collected_data.first.id }
    it { assert_includes @monitor.listeners.keys, "test" }
  end

  describe "#unsubscribe" do
    describe "when we do not use any namespace" do
      before do
        @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
        @collected_data = []
        @block_listener = proc { |event| @collected_data << event }
        @monitor.subscribe("test", &@block_listener)
      end

      it "expect to remove the listener from the event" do
        @monitor.unsubscribe(@block_listener)
        @monitor.instrument("test") { 1 }

        assert_empty @collected_data
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes @monitor.listeners["test"], @block_listener
        @monitor.unsubscribe(@block_listener)

        refute_includes @monitor.listeners["test"], @block_listener
      end
    end

    describe "when we do use a namespace" do
      before do
        @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, "namespace")
        @collected_data = []
        @block_listener = proc { |event| @collected_data << event }
        @monitor.subscribe("test.namespace", &@block_listener)
      end

      it "expect to remove the listener from the namespaced event" do
        @monitor.unsubscribe(@block_listener)
        @monitor.instrument("test") { 1 }

        assert_empty @collected_data
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes @monitor.listeners["test.namespace"], @block_listener
        @monitor.unsubscribe(@block_listener)

        refute_includes @monitor.listeners["test.namespace"], @block_listener
      end
    end

    describe "when we have an object listener" do
      before do
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

      it "expect to remove the object listener" do
        @monitor.unsubscribe(@listener)
        @monitor.instrument("test") { 1 }

        assert_empty @listener.accu
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes @monitor.listeners["test"], @listener
        @monitor.unsubscribe(@listener)

        refute_includes @monitor.listeners["test"], @listener
      end
    end

    describe "when trying to unsubscribe a listener that was never subscribed" do
      it "expect not to raise any errors" do
        monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)
        unsubscribed_listener = proc { |event| event }

        monitor.unsubscribe(unsubscribed_listener)
      end
    end

    describe "when multiple listeners are subscribed and we unsubscribe one" do
      before do
        @monitor = Karafka::Core::Monitoring::Monitor.new(@notifications_bus, nil)

        @first_collected = []
        @second_collected = []

        @first_listener = proc { |event| @first_collected << event }
        @second_listener = proc { |event| @second_collected << event }

        @monitor.subscribe("test", &@first_listener)
        @monitor.subscribe("test", &@second_listener)
        @first_listener_added = @monitor.listeners["test"][0]
      end

      it "expect to only remove the specified listener" do
        @monitor.unsubscribe(@first_listener_added)
        @monitor.instrument("test") { 1 }

        assert_empty @first_collected
        refute_empty @second_collected
      end

      it "expect to keep the other listener in the listeners hash" do
        assert_includes @monitor.listeners["test"], @first_listener
        assert_includes @monitor.listeners["test"], @second_listener
        @monitor.unsubscribe(@first_listener_added)

        assert_same false, @monitor.listeners["test"].include?(@first_listener_added)
        assert_includes @monitor.listeners["test"], @second_listener
      end
    end

    describe "when listener is subscribed to multiple events" do
      before do
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

      it "expect to remove the listener from all events" do
        @monitor.unsubscribe(@multi_event_listener)
        @monitor.instrument("test") { 1 }
        @monitor.instrument("test.namespace") { 1 }

        assert_empty @multi_event_listener.accu
      end
    end
  end
end
