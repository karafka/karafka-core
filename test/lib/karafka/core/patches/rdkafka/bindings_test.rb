# frozen_string_literal: true

class KarafkaCorePatchesRdkafkaBindingsTest < Minitest::Test
  def test_error_callback_includes_instance_name
    config = { "bootstrap.servers": "localhost:10092" }
    producer = Rdkafka::Config.new(config).producer

    errors = []
    callback = ->(*args) { errors << args }

    Rdkafka::Config.error_callback.add("test", callback)

    producer.produce(topic: "test", payload: "1")
    sleep(0.01) while errors.empty?

    assert_includes errors.first.first, "rdkafka#producer"
    assert_equal :transport, errors.first.last.code
  ensure
    Rdkafka::Config.error_callback.delete("test")
  end
end
