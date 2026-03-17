# frozen_string_literal: true

describe_current do
  subject(:decorator) { described_class.new }

  let(:emitted_stats1) do
    {
      "string" => "value1",
      "float" => 10.4,
      "int" => 112,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 123
          }
        }
      }
    }
  end

  let(:emitted_stats2) do
    {
      "string" => "value2",
      "float" => 10.8,
      "int" => 130,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 153
          }
        }
      }
    }
  end

  let(:emitted_stats3) do
    {
      "string" => "value3",
      "float" => 11.8,
      "int" => 10,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 2
          }
        }
      }
    }
  end

  let(:broker_scope) { %w[nested brokers localhost:9092/2] }

  context "when it is a first stats emit" do
    subject(:decorated) { decorator.call(emitted_stats1) }

    it { assert_equal "value1", decorated["string"] }
    it { refute decorated.key?("string_d") }
    it { assert_equal 0, decorated["float_d"] }
    it { assert_equal 0, decorated["int_d"] }
    it { assert_equal 0, decorated.dig(*broker_scope)["txbytes_d"] }
    it { assert_predicate decorated, :frozen? }
  end

  context "when it is a second stats emit" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    it { assert_equal "value2", decorated["string"] }
    it { refute decorated.key?("string_d") }
    it { assert_in_delta(0.4, decorated["float_d"].round(10)) }
    it { assert_equal 18, decorated["int_d"] }
    it { assert_equal 30, decorated.dig(*broker_scope)["txbytes_d"] }
    it { assert_predicate decorated, :frozen? }
  end

  context "when it is a third stats emit" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
      decorator.call(emitted_stats3)
    end

    it { assert_equal "value3", decorated["string"] }
    it { refute decorated.key?("string_d") }
    it { refute decorated.key?("string_fd") }
    it { assert_in_delta(1.0, decorated["float_d"].round(10)) }
    it { assert_in_delta 0, decorated["float_fd"], 5 }
    it { assert_equal(-120, decorated["int_d"]) }
    it { assert_in_delta 0, decorated["int_fd"], 5 }
    it { assert_equal(-151, decorated.dig(*broker_scope)["txbytes_d"]) }
    it { assert_in_delta 0, decorated.dig(*broker_scope)["txbytes_fd"], 5 }
    it { assert_predicate decorated, :frozen? }
    it { refute decorated.key?("float_d_d") }
  end

  context "when a broker is no longer present" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    before { emitted_stats2["nested"] = {} }

    it { assert_equal "value2", decorated["string"] }
    it { refute decorated.key?("string_d") }
    it { refute decorated.key?("string_fd") }
    it { assert_in_delta(0.4, decorated["float_d"].round(10)) }
    it { assert_in_delta 0, decorated["float_fd"], 5 }
    it { assert_equal 18, decorated["int_d"] }
    it { assert_in_delta 0, decorated["int_fd"], 5 }
    it { assert_equal({}, decorated["nested"]) }
    it { assert_predicate decorated, :frozen? }
    it { refute decorated.key?("float_d_d") }
  end

  context "when broker was introduced later on" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    before { emitted_stats1["nested"] = {} }

    it { assert_equal "value2", decorated["string"] }
    it { refute decorated.key?("string_d") }
    it { assert_in_delta(0.4, decorated["float_d"].round(10)) }
    it { assert_in_delta 0, decorated["float_fd"], 5 }
    it { assert_equal 18, decorated["int_d"] }
    it { assert_in_delta 0, decorated["int_fd"], 5 }
    it { assert_equal 0, decorated.dig(*broker_scope)["txbytes_d"] }
    it { assert_in_delta 0, decorated.dig(*broker_scope)["txbytes_fd"], 5 }
    it { assert_predicate decorated, :frozen? }
    it { refute decorated.key?("float_d_d") }
  end

  context "when value remains unchanged over time" do
    subject(:decorated) do
      # First one will set initial state
      decorator.call(deep_copy.call)
      # Second one will build first deltas with freeze duration of zero
      decorator.call(deep_copy.call)
      sleep(0.01)
      # Third one will allow for proper freeze duration computation
      decorator.call(deep_copy.call)
    end

    let(:deep_copy) { -> { Marshal.load(Marshal.dump(emitted_stats1)) } }

    it { refute decorated.key?("string_d") }
    it { refute decorated.key?("string_fd") }
    it { assert_equal 0, decorated["float_d"] }
    it { assert_in_delta 10, decorated["float_fd"], 5 }
    it { assert_equal 0, decorated["int_d"] }
    it { assert_in_delta 10, decorated["int_fd"], 5 }
    it { assert_predicate decorated, :frozen? }
    it { refute decorated.key?("float_d_d") }
  end

  context "when value remains unchanged over multiple occurrences and time" do
    subject(:decorated) do
      # First one will set initial state
      decorator.call(deep_copy.call)
      # Second one will build first deltas with freeze duration of zero
      decorator.call(deep_copy.call)
      sleep(0.01)
      # Third one will allow for proper freeze duration computation
      decorator.call(deep_copy.call)
      sleep(0.01)
      decorator.call(deep_copy.call)
    end

    let(:deep_copy) { -> { Marshal.load(Marshal.dump(emitted_stats1)) } }

    it { refute decorated.key?("string_d") }
    it { refute decorated.key?("string_fd") }
    it { assert_equal 0, decorated["float_d"] }
    it { assert_in_delta 20, decorated["float_fd"], 5 }
    it { assert_equal 0, decorated["int_d"] }
    # On slow CIs this value tends to grow and crash
    it { assert_in_delta 20, decorated["int_fd"], 15 }
    it { assert_predicate decorated, :frozen? }
    it { refute decorated.key?("float_d_d") }
  end

  context "when a value type changed from non-numeric to numeric between emissions" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    before do
      # In the first emission, txbytes is a string (unusual but defensive)
      emitted_stats1["nested"]["brokers"]["localhost:9092/2"]["txbytes"] = "not_a_number"
    end

    # When previous value was non-numeric but current is numeric, no delta should be computed
    it { refute decorated.dig(*broker_scope).key?("txbytes_d") }
    it { refute decorated.dig(*broker_scope).key?("txbytes_fd") }
    it { assert_equal 153, decorated.dig(*broker_scope)["txbytes"] }
    it { assert_predicate decorated, :frozen? }
  end

  context "when excluded_keys are configured" do
    subject(:decorator) { described_class.new(excluded_keys: %w[nested]) }

    context "when it is a first stats emit" do
      subject(:decorated) { decorator.call(emitted_stats1) }

      it { assert_equal 0, decorated["float_d"] }
      it { assert_equal 0, decorated["int_d"] }
      it { assert_predicate decorated, :frozen? }

      it "does not decorate excluded subtrees" do
        expected = { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }

        assert_equal(expected, decorated["nested"])
        refute decorated["nested"]["brokers"]["localhost:9092/2"].key?("txbytes_d")
      end
    end

    context "when it is a second stats emit" do
      subject(:decorated) do
        decorator.call(emitted_stats1)
        decorator.call(emitted_stats2)
      end

      it { assert_in_delta(0.4, decorated["float_d"].round(10)) }
      it { assert_equal 18, decorated["int_d"] }
      it { assert_predicate decorated, :frozen? }

      it "does not decorate excluded subtrees" do
        refute decorated["nested"]["brokers"]["localhost:9092/2"].key?("txbytes_d")
        refute decorated["nested"]["brokers"]["localhost:9092/2"].key?("txbytes_fd")
      end
    end
  end

  context "when excluded_keys target a numeric key" do
    let(:decorator) { described_class.new(excluded_keys: %w[int]) }

    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    it { assert_in_delta(0.4, decorated["float_d"].round(10)) }
    it { assert_equal 130, decorated["int"] }
    it { refute decorated.key?("int_d") }
    it { refute decorated.key?("int_fd") }
    it { assert_predicate decorated, :frozen? }
  end

  context "when no excluded_keys are configured" do
    let(:decorator) { described_class.new }

    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    it { assert_equal 18, decorated["int_d"] }
    it { assert_equal 30, decorated.dig(*broker_scope)["txbytes_d"] }
  end

  context "when only_keys are configured" do
    let(:decorator) { described_class.new(only_keys: %w[int]) }

    context "when it is a first stats emit" do
      subject(:decorated) { decorator.call(emitted_stats1) }

      it { assert_equal 0, decorated["int_d"] }
      it { assert_predicate decorated, :frozen? }

      it "does not decorate non-listed numeric keys" do
        refute decorated.key?("float_d")
        refute decorated.key?("float_fd")
      end

      it "preserves non-listed numeric values" do
        assert_in_delta 10.4, decorated["float"]
      end

      it "preserves string values" do
        assert_equal "value1", decorated["string"]
      end
    end

    context "when it is a second stats emit" do
      subject(:decorated) do
        decorator.call(emitted_stats1)
        decorator.call(emitted_stats2)
      end

      it { assert_equal 18, decorated["int_d"] }
      it { assert_predicate decorated, :frozen? }

      it "does not decorate non-listed numeric keys" do
        refute decorated.key?("float_d")
        refute decorated.key?("float_fd")
      end
    end

    context "when only_keys targets a nested value" do
      let(:decorator) { described_class.new(only_keys: %w[txbytes]) }

      subject(:decorated) do
        decorator.call(emitted_stats1)
        decorator.call(emitted_stats2)
      end

      it "decorates matching keys in nested hashes" do
        assert_equal 30, decorated.dig(*broker_scope)["txbytes_d"]
      end

      it "does not decorate non-listed root keys" do
        refute decorated.key?("int_d")
        refute decorated.key?("float_d")
      end
    end
  end

  context "when only_keys and excluded_keys are combined" do
    let(:decorator) { described_class.new(excluded_keys: %w[nested], only_keys: %w[int]) }

    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    it { assert_equal 18, decorated["int_d"] }
    it { assert_predicate decorated, :frozen? }

    it "does not decorate non-listed keys" do
      refute decorated.key?("float_d")
    end

    it "does not recurse into excluded subtrees" do
      refute decorated.dig(*broker_scope).key?("txbytes_d")
    end
  end

  context "when only_keys value remains unchanged over time" do
    subject(:decorated) do
      decorator.call(deep_copy.call)
      decorator.call(deep_copy.call)
      sleep(0.01)
      decorator.call(deep_copy.call)
    end

    let(:decorator) { described_class.new(only_keys: %w[int]) }
    let(:deep_copy) { -> { Marshal.load(Marshal.dump(emitted_stats1)) } }

    it { assert_equal 0, decorated["int_d"] }
    it { assert_in_delta 10, decorated["int_fd"], 5 }

    it "does not decorate non-listed keys" do
      refute decorated.key?("float_d")
      refute decorated.key?("float_fd")
    end
  end

  context "when only_keys is used with librdkafka-like structure" do
    let(:decorator) { described_class.new(only_keys: %w[rxmsgs txbytes consumer_lag]) }

    let(:rdkafka_stats1) do
      {
        "rxmsgs" => 100,
        "name" => "consumer-1",
        "brokers" => {
          "localhost:9092/0" => {
            "txbytes" => 500,
            "rxbytes" => 300,
            "nodeid" => 0
          }
        },
        "topics" => {
          "events" => {
            "age" => 1000,
            "partitions" => {
              "0" => {
                "consumer_lag" => 50,
                "hi_offset" => 1000,
                "txmsgs" => 200
              },
              "1" => {
                "consumer_lag" => 30,
                "hi_offset" => 800,
                "txmsgs" => 150
              }
            }
          }
        },
        "cgrp" => {
          "stateage" => 5000,
          "rebalance_cnt" => 2
        }
      }
    end

    let(:rdkafka_stats2) do
      {
        "rxmsgs" => 150,
        "name" => "consumer-1",
        "brokers" => {
          "localhost:9092/0" => {
            "txbytes" => 700,
            "rxbytes" => 500,
            "nodeid" => 0
          }
        },
        "topics" => {
          "events" => {
            "age" => 2000,
            "partitions" => {
              "0" => {
                "consumer_lag" => 40,
                "hi_offset" => 1100,
                "txmsgs" => 250
              },
              "1" => {
                "consumer_lag" => 25,
                "hi_offset" => 900,
                "txmsgs" => 200
              }
            }
          }
        },
        "cgrp" => {
          "stateage" => 6000,
          "rebalance_cnt" => 2
        }
      }
    end

    subject(:decorated) do
      decorator.call(rdkafka_stats1)
      decorator.call(rdkafka_stats2)
    end

    it "decorates root only_keys" do
      assert_equal 50, decorated["rxmsgs_d"]
    end

    it "does not decorate non-listed root keys" do
      refute decorated.key?("name_d")
    end

    it "decorates broker only_keys" do
      assert_equal 200, decorated["brokers"]["localhost:9092/0"]["txbytes_d"]
    end

    it "does not decorate non-listed broker keys" do
      refute decorated["brokers"]["localhost:9092/0"].key?("rxbytes_d")
    end

    it "decorates partition only_keys" do
      assert_equal(-10, decorated.dig("topics", "events", "partitions", "0")["consumer_lag_d"])
      assert_equal(-5, decorated.dig("topics", "events", "partitions", "1")["consumer_lag_d"])
    end

    it "does not decorate non-listed partition keys" do
      refute decorated.dig("topics", "events", "partitions", "0").key?("txmsgs_d")
      refute decorated.dig("topics", "events", "partitions", "0").key?("hi_offset_d")
    end

    it "does not decorate non-listed topic keys" do
      refute decorated.dig("topics", "events").key?("age_d")
    end

    it { assert_predicate decorated, :frozen? }
  end

  context "when only_keys previous value type changed to non-numeric" do
    let(:decorator) { described_class.new(only_keys: %w[val]) }

    subject(:decorated) do
      decorator.call({ "val" => "not_numeric" })
      decorator.call({ "val" => 10 })
    end

    it { refute decorated.key?("val_d") }
  end

  context "when a value type changed from numeric to non-numeric between emissions" do
    subject(:decorated) do
      decorator.call(emitted_stats1)
      decorator.call(emitted_stats2)
    end

    before do
      # In the second emission, txbytes changed to a string
      emitted_stats2["nested"]["brokers"]["localhost:9092/2"]["txbytes"] = "not_a_number"
    end

    # Non-numeric values are never decorated
    it { refute decorated.dig(*broker_scope).key?("txbytes_d") }
    it { refute decorated.dig(*broker_scope).key?("txbytes_fd") }
    it { assert_equal "not_a_number", decorated.dig(*broker_scope)["txbytes"] }
    it { assert_predicate decorated, :frozen? }
  end
end
