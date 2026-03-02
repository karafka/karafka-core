# frozen_string_literal: true

describe_current do
  subject(:monitor) do
    described_class.new(
      notifications_bus,
      namespace
    )
  end

  let(:notifications_bus) { Karafka::Core::Monitoring::Notifications.new }

  before do
    notifications_bus.register_event("test")
    notifications_bus.register_event("test.namespace")
  end

  context "when we do not use any namespace" do
    let(:namespace) { nil }
    let(:collected_data) { [] }

    before do
      collected = collected_data

      monitor.subscribe("test") do |event|
        collected << event
      end

      monitor.instrument("test") { 1 }
    end

    it { assert_equal 1, collected_data.size }
    it { assert_equal "test", collected_data.first.id }
    it { assert_includes monitor.listeners.keys, "test" }
    it { assert_kind_of Array, monitor.listeners["test"] }
  end

  context "when we do use a namespace" do
    let(:namespace) { "namespace" }
    let(:collected_data) { [] }

    before do
      collected = collected_data

      monitor.subscribe("test.namespace") do |event|
        collected << event
      end

      monitor.instrument("test") { 1 }
    end

    it { assert_equal 1, collected_data.size }
    it { assert_equal "test.namespace", collected_data.first.id }
    it { assert_includes monitor.listeners.keys, "test" }
  end

  describe "#unsubscribe" do
    context "when we do not use any namespace" do
      let(:namespace) { nil }
      let(:collected_data) { [] }
      let(:block_listener) do
        proc do |event|
          collected_data << event
        end
      end

      before do
        monitor.subscribe("test", &block_listener)
      end

      it "expect to remove the listener from the event" do
        monitor.unsubscribe(block_listener)
        monitor.instrument("test") { 1 }

        assert_empty collected_data
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes monitor.listeners["test"], block_listener
        monitor.unsubscribe(block_listener)

        refute_includes monitor.listeners["test"], block_listener
      end
    end

    context "when we do use a namespace" do
      let(:namespace) { "namespace" }
      let(:collected_data) { [] }
      let(:block_listener) do
        proc do |event|
          collected_data << event
        end
      end

      before do
        monitor.subscribe("test.namespace", &block_listener)
      end

      it "expect to remove the listener from the namespaced event" do
        monitor.unsubscribe(block_listener)
        monitor.instrument("test") { 1 }

        assert_empty collected_data
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes monitor.listeners["test.namespace"], block_listener
        monitor.unsubscribe(block_listener)

        refute_includes monitor.listeners["test.namespace"], block_listener
      end
    end

    context "when we have an object listener" do
      let(:namespace) { nil }
      let(:listener_class) do
        Class.new do
          attr_reader :accu

          def initialize
            @accu = []
          end

          def on_test(event)
            @accu << event
          end
        end
      end

      let(:listener) { listener_class.new }

      before do
        monitor.subscribe(listener)
      end

      it "expect to remove the object listener" do
        monitor.unsubscribe(listener)
        monitor.instrument("test") { 1 }

        assert_empty listener.accu
      end

      it "expect to remove the listener from the notifications bus listeners" do
        assert_includes monitor.listeners["test"], listener
        monitor.unsubscribe(listener)

        refute_includes monitor.listeners["test"], listener
      end
    end

    context "when trying to unsubscribe a listener that was never subscribed" do
      let(:namespace) { nil }
      let(:unsubscribed_listener) do
        proc { |event| event }
      end

      it "expect not to raise any errors" do
        monitor.unsubscribe(unsubscribed_listener)
      end
    end

    context "when multiple listeners are subscribed and we unsubscribe one" do
      let(:namespace) { nil }
      let(:first_collected) { [] }
      let(:second_collected) { [] }

      let(:first_listener) do
        proc { |event| first_collected << event }
      end

      let(:second_listener) do
        proc { |event| second_collected << event }
      end

      let(:first_listener_added) do
        monitor.listeners["test"][0]
      end

      before do
        monitor.subscribe("test", &first_listener)
        monitor.subscribe("test", &second_listener)
        first_listener_added
      end

      it "expect to only remove the specified listener" do
        monitor.unsubscribe(first_listener_added)
        monitor.instrument("test") { 1 }

        assert_empty first_collected
        refute_empty second_collected
      end

      it "expect to keep the other listener in the listeners hash" do
        assert_includes monitor.listeners["test"], first_listener
        assert_includes monitor.listeners["test"], second_listener
        monitor.unsubscribe(first_listener_added)

        refute_includes monitor.listeners["test"], first_listener_added
        assert_includes monitor.listeners["test"], second_listener
      end
    end

    context "when listener is subscribed to multiple events" do
      let(:namespace) { nil }
      let(:collected_data) { [] }
      let(:multi_event_listener) do
        Class.new do
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
        end.new
      end

      before do
        monitor.subscribe(multi_event_listener)
      end

      it "expect to remove the listener from all events" do
        monitor.unsubscribe(multi_event_listener)
        monitor.instrument("test") { 1 }
        monitor.instrument("test.namespace") { 1 }

        assert_empty multi_event_listener.accu
      end
    end
  end
end
