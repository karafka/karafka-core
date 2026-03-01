# frozen_string_literal: true

describe_current do
  before do
    @notifications = Karafka::Core::Monitoring::Notifications.new
    @event_name = "message.produced_async"
    @notifications.register_event(@event_name)
  end

  describe "#instrument" do
    it "expect to return blocks execution value" do
      result = rand
      instrumentation = @notifications.instrument(
        @event_name,
        call: self,
        error: StandardError
      ) { result }

      assert_equal result, instrumentation
    end

    describe "when we want to instrument event that was not registered" do
      it "expect to raise error" do
        assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
          @notifications.instrument("na")
        end
      end
    end
  end

  describe "#subscribe" do
    describe "when we have a block based listener" do
      describe "when we try to subscribe to an unsupported event" do
        it "expect to raise error" do
          assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
            @notifications.subscribe("na") { |_event| nil }
          end
        end
      end

      describe "when we try to subscribe to a supported event" do
        it "expect not to raise" do
          @notifications.subscribe(@event_name) { |_event| nil }
        end
      end
    end

    describe "when we have an object listener" do
      it "expect not to raise" do
        listener = Class.new do
          def on_message_produced_async(_event)
            true
          end
        end

        @notifications.subscribe(listener.new)
      end
    end
  end

  describe "#unsubscribe" do
    describe "when we have a block based listener" do
      before do
        @tracked = []
        @block_listener = proc { |event| @tracked << event }
        @notifications.subscribe(@event_name, &@block_listener)
      end

      it "expect to remove the block from the event" do
        @notifications.unsubscribe(@block_listener)
        @notifications.instrument(@event_name)

        assert_empty @tracked
      end

      describe "when the same block is subscribed to multiple events" do
        before do
          @second_event = "message.consumed"
          @notifications.register_event(@second_event)
          @notifications.subscribe(@second_event, &@block_listener)
        end

        it "expect to remove the block from all events" do
          @notifications.unsubscribe(@block_listener)
          @notifications.instrument(@event_name)
          @notifications.instrument(@second_event)

          assert_empty @tracked
        end
      end
    end

    describe "when we have an object listener" do
      before do
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

      it "expect to remove the listener from the event" do
        @notifications.unsubscribe(@listener)
        @notifications.instrument(@event_name)

        assert_empty @listener.accu
      end

      describe "when the listener is subscribed to multiple events" do
        before do
          @second_event = "message.consumed"
          @notifications.register_event(@second_event)
          @notifications.subscribe(@listener)
        end

        it "expect to remove the listener from all events" do
          @notifications.unsubscribe(@listener)
          @notifications.instrument(@event_name)
          @notifications.instrument(@second_event)

          assert_empty @listener.accu
        end
      end
    end

    describe "when trying to unsubscribe a listener that was never subscribed" do
      it "expect not to raise any errors" do
        unsubscribed = Class.new do
          def on_message_produced_async(_event)
            true
          end
        end.new

        @notifications.unsubscribe(unsubscribed)
      end
    end

    describe "when multiple listeners are subscribed and we unsubscribe one" do
      before do
        @tracked_first = []
        @tracked_second = []
        @first_listener = proc { |event| @tracked_first << event }
        @second_listener = proc { |event| @tracked_second << event }
        @notifications.subscribe(@event_name, &@first_listener)
        @notifications.subscribe(@event_name, &@second_listener)
      end

      it "expect to only remove the specified listener" do
        @notifications.unsubscribe(@first_listener)
        @notifications.instrument(@event_name)

        assert_empty @tracked_first
        refute_empty @tracked_second
      end
    end
  end

  describe "#available_events" do
    it { assert_equal [@event_name], @notifications.available_events }
  end

  describe "#clear" do
    describe "without an argument" do
      it "expect not to raise as after clearing subscription should no longer work" do
        @notifications.subscribe(@event_name) { raise }
        @notifications.clear
        @notifications.instrument(@event_name)
      end
    end

    describe "one event given" do
      it "expect to only get one event" do
        instrumented = []
        @notifications.register_event("some-other-event")
        @notifications.subscribe(@event_name) { instrumented.push(1) }
        @notifications.subscribe("some-other-event") { instrumented.push(2) }

        @notifications.clear("some-other-event")
        @notifications.instrument(@event_name)
        @notifications.instrument("some-other-event")

        assert_equal [1], instrumented
      end
    end

    describe "clearing non-existing event" do
      it "expect to raise an error" do
        assert_raises(Karafka::Core::Monitoring::Notifications::EventNotRegistered) do
          @notifications.clear("some-nonexistent-event")
        end
      end
    end
  end

  describe "subscription and instrumentation flow" do
    describe "when we subscribe with a proc listener" do
      it "expect to deliver event" do
        tracked = []
        @notifications.subscribe(@event_name) { |event| tracked << event }
        @notifications.instrument(@event_name)

        assert_equal @event_name, tracked[0].id
      end
    end

    describe "when we subscribe with a class listener" do
      it "expect to deliver event" do
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
  end
end
