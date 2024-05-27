# frozen_string_literal: true

RSpec.describe_current do
  subject(:notifications) { described_class.new }

  let(:event_name) { 'message.produced_async' }
  let(:event_not_registered_error) { Karafka::Core::Monitoring::Notifications::EventNotRegistered }

  before { notifications.register_event(event_name) }

  describe '#instrument' do
    let(:result) { rand }
    let(:instrumentation) do
      notifications.instrument(
        event_name,
        call: self,
        error: StandardError
      ) { result }
    end

    it 'expect to return blocks execution value' do
      expect(instrumentation).to eq result
    end

    context 'when we want to instrument event that was not registered' do
      it 'expect to raise error' do
        expected_error = event_not_registered_error
        expect { notifications.instrument('na') }.to raise_error(expected_error)
      end
    end
  end

  describe '#subscribe' do
    context 'when we have a block based listener' do
      let(:subscription) {  {} }

      context 'when we try to subscribe to an unsupported event' do
        it do
          expected_error = event_not_registered_error
          expect { notifications.subscribe('na') {} }.to raise_error expected_error
        end
      end

      context 'when we try to subscribe to a supported event' do
        let(:event_name) { 'message.produced_async' }

        it { expect { subscription }.not_to raise_error }
      end
    end

    context 'when we have an object listener' do
      let(:subscription) { notifications.subscribe(listener.new) }
      let(:listener) do
        Class.new do
          def on_message_produced_async(_event)
            true
          end
        end
      end

      it { expect { subscription }.not_to raise_error }
    end
  end

  describe '#clear' do

    describe 'without an argument' do
      before { notifications.subscribe(event_name) { raise } }

      it 'expect not to raise any errors as after clearing subscription should no longer work' do
        notifications.clear
        notifications.instrument(event_name)
      end
    end

    describe 'one event given' do
      let(:instrumented) { [] }
      before do
        notifications.register_event('some-other-event')
        notifications.subscribe(event_name) { instrumented.push(1) } # it's fine
        notifications.subscribe('some-other-event') { instrumented.push(2) }
      end

      it 'expect to only get one event' do
        notifications.clear('some-other-event')
        notifications.instrument(event_name)
        notifications.instrument('some-other-event')
        expect(instrumented).to eq([1])
      end
    end

    describe 'clearing non-existing event' do
      it 'should raise an error' do
        expect { notifications.clear('some-nonexistent-event') }
          .to raise_error(event_not_registered_error)
      end
    end
  end

  describe 'subscription and instrumentation flow' do
    context 'when we subscribe with a proc listener' do
      let(:tracked) { [] }

      before do
        notifications.subscribe(event_name) do |event|
          tracked << event
        end

        notifications.instrument(event_name)
      end

      it { expect(tracked[0].id).to eq(event_name) }
    end

    context 'when we subscribe with a class listener' do
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

      it { expect(listener.accu[0].id).to eq(event_name) }
    end
  end
end
