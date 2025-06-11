# frozen_string_literal: true

RSpec.describe_current do
  subject(:producer) do
    config = { 'bootstrap.servers': 'localhost:10092' }
    Rdkafka::Config.new(config).producer
  end

  describe '#build_error_callback' do
    let(:errors) { [] }
    let(:callback) { ->(*args) { errors << args } }

    before { ::Rdkafka::Config.error_callback.add('test', callback) }

    after { ::Rdkafka::Config.error_callback.delete('test') }

    it 'expect to inject instance name to the error callback' do
      producer.produce(topic: 'test', payload: '1')
      sleep(0.01) while errors.empty?

      expect(errors.first.first).to include('rdkafka#producer')
      expect(errors.first.last.code).to eq(:transport)
    end
  end
end
