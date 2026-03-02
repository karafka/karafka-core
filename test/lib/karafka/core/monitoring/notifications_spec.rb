# frozen_string_literal: true

require "test_helper"

describe_current do
  subject(:notifications) { described_class.new }

  let(:event_name) { "message.produced_async" }
  let(:event_not_registered_error) { Karafka::Core::Monitoring::Notifications::EventNotRegistered }

  before { notifications.register_event(event_name) }

  describe "#instrument" do
    let(:result) { rand }
    let(:instrumentation) do
      notifications.instrument(
        event_name,
        call: self,
        error: StandardError
      ) { result }
    end

    it "expect to return blocks execution value" do
      assert_equal result, instrumentation
    end

    context "when we want to instrument event that was not registered" do
      it "expect to raise error" do
        expected_error = event_not_registered_error
        assert_raises(expected_error) { notifications.instrument("na") }
      end
    end
  end

  describe "#subscribe" do
    context "when we have a block based listener" do
      let(:subscription) { notifications.subscribe(event_name) { |_event| nil } }

      context "when we try to subscribe to an unsupported event" do
        it "expect to raise error" do
          expected_error = event_not_registered_error
          assert_raises(expected_error) { notifications.subscribe("na") { |_event| nil } }
        end
      end

      context "when we try to subscribe to a supported event" do
        let(:event_name) { "message.produced_async" }

        it { subscription }
      end
    end

    context "when we have an object listener" do
      let(:subscription) { notifications.subscribe(listener.new) }
      let(:listener) do
        Class.new do
          def on_message_produced_async(_event)
            true
          end
        end
      end

      it { subscription }
    end
  end

  describe "#unsubscribe" do
    context "when we have a block based listener" do
      let(:tracked) { [] }
      let(:block_listener) do
        proc do |event|
          tracked << event
        end
      end

      before do
        notifications.subscribe(event_name, &block_listener)
      end

      it "expect to remove the block from the event" do
        notifications.unsubscribe(block_listener)
        notifications.instrument(event_name)

        assert_empty tracked
      end

      context "when the same block is subscribed to multiple events" do
        let(:second_event) { "message.consumed" }

        before do
          notifications.register_event(second_event)
          notifications.subscribe(second_event, &block_listener)
        end

        it "expect to remove the block from all events" do
          notifications.unsubscribe(block_listener)
          notifications.instrument(event_name)
          notifications.instrument(second_event)

          assert_empty tracked
        end
      end
    end

    context "when we have an object listener" do
      let(:listener_class) do
        Class.new do
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
      end

      let(:listener) { listener_class.new }

      before do
        notifications.subscribe(listener)
      end

      it "expect to remove the listener from the event" do
        notifications.unsubscribe(listener)
        notifications.instrument(event_name)

        assert_empty listener.accu
      end

      context "when the listener is subscribed to multiple events" do
        let(:second_event) { "message.consumed" }

        before do
          notifications.register_event(second_event)
          notifications.subscribe(listener)
        end

        it "expect to remove the listener from all events" do
          notifications.unsubscribe(listener)
          notifications.instrument(event_name)
          notifications.instrument(second_event)

          assert_empty listener.accu
        end
      end
    end

    context "when trying to unsubscribe a listener that was never subscribed" do
      let(:unsubscribed_listener) do
        Class.new do
          def on_message_produced_async(_event)
            true
          end
        end.new
      end

      it "expect not to raise any errors" do
        notifications.unsubscribe(unsubscribed_listener)
      end
    end

    context "when multiple listeners are subscribed and we unsubscribe one" do
      let(:tracked_first) { [] }
      let(:tracked_second) { [] }

      let(:first_listener) do
        proc { |event| tracked_first << event }
      end

      let(:second_listener) do
        proc { |event| tracked_second << event }
      end

      before do
        notifications.subscribe(event_name, &first_listener)
        notifications.subscribe(event_name, &second_listener)
      end

      it "expect to only remove the specified listener" do
        notifications.unsubscribe(first_listener)
        notifications.instrument(event_name)

        assert_empty tracked_first
        refute_empty tracked_second
      end
    end
  end

  describe "#available_events" do
    it { assert_equal [event_name], notifications.available_events }
  end

  describe "#clear" do
    describe "without an argument" do
      before { notifications.subscribe(event_name) { raise } }

      it "expect not to raise any errors as after clearing subscription should no longer work" do
        notifications.clear
        notifications.instrument(event_name)
      end
    end

    describe "one event given" do
      let(:instrumented) { [] }

      before do
        notifications.register_event("some-other-event")
        notifications.subscribe(event_name) { instrumented.push(1) }
        notifications.subscribe("some-other-event") { instrumented.push(2) }
      end

      it "expect to only get one event" do
        notifications.clear("some-other-event")
        notifications.instrument(event_name)
        notifications.instrument("some-other-event")

        assert_equal [1], instrumented
      end
    end

    describe "clearing non-existing event" do
      it "expect to raise an error" do
        assert_raises(event_not_registered_error) {
          notifications.clear("some-nonexistent-event")
        }
      end
    end
  end

  describe "subscription and instrumentation flow" do
    context "when we subscribe with a proc listener" do
      let(:tracked) { [] }

      before do
        notifications.subscribe(event_name) do |event|
          tracked << event
        end

        notifications.instrument(event_name)
      end

      it { assert_equal event_name, tracked[0].id }
    end

    context "when we subscribe with a class listener" do
      let(:listener_class) do
        Class.new do
          attr_reader :accu

          def initialize
            @accu = []
          end

          def on_message_produced_async(event)
            @accu << event
          end
        end
      end

      let(:listener) { listener_class.new }

      before do
        notifications.subscribe(listener)
        notifications.instrument(event_name)
      end

      it { assert_equal event_name, listener.accu[0].id }
    end
  end
end
