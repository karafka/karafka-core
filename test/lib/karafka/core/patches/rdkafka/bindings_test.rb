# frozen_string_literal: true

# The regression tests below temporarily replace singleton methods (rd_kafka_name, build_fatal)
# to intercept FFI calls without a live broker. Redefining a method emits a "method redefined"
# warning, which the test suite otherwise escalates to an error; allow it for this file only.
Warning.ignore(:method_redefined, __FILE__)

describe_current do
  subject(:producer) do
    config = { "bootstrap.servers": "localhost:10092" }
    Rdkafka::Config.new(config).producer
  end

  # Temporarily replaces a singleton method with the given callable for the duration of the
  # block, restoring the original afterwards. Used to intercept the FFI calls so the buggy
  # behavior fails an assertion instead of dereferencing a bad pointer and segfaulting.
  def with_stubbed(mod, name, replacement)
    original = mod.method(name)
    mod.define_singleton_method(name, replacement)
    yield
  ensure
    mod.define_singleton_method(name, original)
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

    # Invoke the patched FFI callback directly the way librdkafka does, so we can cover the
    # edge cases without a live broker. rd_kafka_name / build_fatal are stubbed so the buggy
    # behavior fails the assertion instead of dereferencing a bad pointer and segfaulting.
    describe "when librdkafka invokes the callback directly" do
      let(:fatal_code) { ::Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL }

      it "does not dereference a null client pointer" do
        # Regression: a NULL rd_kafka_t was passed straight to rd_kafka_name, dereferencing it
        # and segfaulting. With the guard, rd_kafka_name is not called and the name is nil.
        names_requested = []
        track_name = lambda do |ptr|
          names_requested << ptr
          "name"
        end

        with_stubbed(::Rdkafka::Bindings, :rd_kafka_name, track_name) do
          ::Rdkafka::Bindings::ErrorCallback.call(
            ::FFI::Pointer::NULL, -195, "boom", ::FFI::Pointer::NULL
          )
        end

        assert_empty names_requested
        assert_nil errors.first.first
      end

      it "resolves fatal errors through build_fatal" do
        # Regression: ERR__FATAL was reported as the generic fatal marker via RdkafkaError.new
        # instead of being resolved to the real underlying error via build_fatal.
        fatal_kwargs = []
        fatal_error = ::Rdkafka::RdkafkaError.new(fatal_code, broker_message: "x", fatal: true)
        build_fatal = lambda do |_client_ptr, **kwargs|
          fatal_kwargs << kwargs
          fatal_error
        end

        with_stubbed(::Rdkafka::Bindings, :rd_kafka_name, ->(_ptr) { "name" }) do
          with_stubbed(::Rdkafka::RdkafkaError, :build_fatal, build_fatal) do
            ::Rdkafka::Bindings::ErrorCallback.call(
              ::FFI::Pointer::NULL, fatal_code, "boom", ::FFI::Pointer::NULL
            )
          end
        end

        refute_empty fatal_kwargs
        assert_same fatal_error, errors.first.last
      end
    end
  end
end
