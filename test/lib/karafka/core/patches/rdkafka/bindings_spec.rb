# frozen_string_literal: true

require "test_helper"

describe_current do
  subject(:producer) do
    config = { "bootstrap.servers": "localhost:10092" }
    Rdkafka::Config.new(config).producer
  end

  describe "#build_error_callback" do
    let(:errors) { [] }
    let(:callback) { ->(*args) { errors << args } }

    before { Rdkafka::Config.error_callback.add("test", callback) }

    after { Rdkafka::Config.error_callback.delete("test") }

    it "expect to inject instance name to the error callback" do
      producer.produce(topic: "test", payload: "1")
      sleep(0.01) while errors.empty?

      assert_includes errors.first.first, "rdkafka#producer"
      assert_equal :transport, errors.first.last.code
    end
  end
end
