# frozen_string_literal: true

describe_current do
  before do
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
    @broker_scope = %w[nested brokers localhost:9092/2]
  end

  def emited_stats1
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

  def emited_stats2
    {
      "string" => "value2", "float" => 10.8, "int" => 130,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 153 } } }
    }
  end

  def emited_stats3
    {
      "string" => "value3", "float" => 11.8, "int" => 10,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 2 } } }
    }
  end

  def deep_copy
    Marshal.load(Marshal.dump(emited_stats1))
  end

  describe "when it is a first stats emit" do
    it { assert_equal "value1", @decorator.call(emited_stats1)["string"] }
    it { assert_same false, @decorator.call(emited_stats1).key?("string_d") }
    it { assert_equal 0, @decorator.call(emited_stats1)["float_d"] }
    it { assert_equal 0, @decorator.call(emited_stats1)["int_d"] }
    it { assert_equal 0, @decorator.call(emited_stats1).dig(*@broker_scope)["txbytes_d"] }
    it { assert_predicate @decorator.call(emited_stats1), :frozen? }
  end

  describe "when it is a second stats emit" do
    before do
      @decorator.call(emited_stats1)
      @decorated = @decorator.call(emited_stats2)
    end

    it { assert_equal "value2", @decorated["string"] }
    it { assert_same false, @decorated.key?("string_d") }
    it { assert_in_delta(0.4, @decorated["float_d"].round(10)) }
    it { assert_equal 18, @decorated["int_d"] }
    it { assert_equal 30, @decorated.dig(*@broker_scope)["txbytes_d"] }
    it { assert_predicate @decorated, :frozen? }
  end

  describe "when it is a third stats emit" do
    before do
      @decorator.call(emited_stats1)
      @decorator.call(emited_stats2)
      @decorated = @decorator.call(emited_stats3)
    end

    it { assert_equal "value3", @decorated["string"] }
    it { assert_same false, @decorated.key?("string_d") }
    it { assert_same false, @decorated.key?("string_fd") }
    it { assert_in_delta(1.0, @decorated["float_d"].round(10)) }
    it { assert_in_delta 0, @decorated["float_fd"], 5 }
    it { assert_equal(-120, @decorated["int_d"]) }
    it { assert_in_delta 0, @decorated["int_fd"], 5 }
    it { assert_equal(-151, @decorated.dig(*@broker_scope)["txbytes_d"]) }
    it { assert_in_delta 0, @decorated.dig(*@broker_scope)["txbytes_fd"], 5 }
    it { assert_predicate @decorated, :frozen? }
    it { assert_same false, @decorated.key?("float_d_d") }
  end

  describe "when a broker is no longer present" do
    before do
      @decorator.call(emited_stats1)
      stats_without_broker = {
        "string" => "value2", "float" => 10.8, "int" => 130,
        "nested" => {}
      }
      @decorated = @decorator.call(stats_without_broker)
    end

    it { assert_equal "value2", @decorated["string"] }
    it { assert_same false, @decorated.key?("string_d") }
    it { assert_same false, @decorated.key?("string_fd") }
    it { assert_in_delta(0.4, @decorated["float_d"].round(10)) }
    it { assert_in_delta 0, @decorated["float_fd"], 5 }
    it { assert_equal 18, @decorated["int_d"] }
    it { assert_in_delta 0, @decorated["int_fd"], 5 }
    it { assert_equal({}, @decorated["nested"]) }
    it { assert_predicate @decorated, :frozen? }
    it { assert_same false, @decorated.key?("float_d_d") }
  end

  describe "when broker was introduced later on" do
    before do
      stats_without_broker = {
        "string" => "value1", "float" => 10.4, "int" => 112,
        "nested" => {}
      }
      @decorator.call(stats_without_broker)
      @decorated = @decorator.call(emited_stats2)
    end

    it { assert_equal "value2", @decorated["string"] }
    it { assert_same false, @decorated.key?("string_d") }
    it { assert_in_delta(0.4, @decorated["float_d"].round(10)) }
    it { assert_in_delta 0, @decorated["float_fd"], 5 }
    it { assert_equal 18, @decorated["int_d"] }
    it { assert_in_delta 0, @decorated["int_fd"], 5 }
    it { assert_equal 0, @decorated.dig(*@broker_scope)["txbytes_d"] }
    it { assert_in_delta 0, @decorated.dig(*@broker_scope)["txbytes_fd"], 5 }
    it { assert_predicate @decorated, :frozen? }
    it { assert_same false, @decorated.key?("float_d_d") }
  end

  describe "when value remains unchanged over time" do
    before do
      @decorator.call(deep_copy)
      @decorator.call(deep_copy)
      sleep(0.01)
      @decorated = @decorator.call(deep_copy)
    end

    it { assert_same false, @decorated.key?("string_d") }
    it { assert_same false, @decorated.key?("string_fd") }
    it { assert_equal 0, @decorated["float_d"] }
    it { assert_in_delta 10, @decorated["float_fd"], 5 }
    it { assert_equal 0, @decorated["int_d"] }
    it { assert_in_delta 10, @decorated["int_fd"], 5 }
    it { assert_predicate @decorated, :frozen? }
    it { assert_same false, @decorated.key?("float_d_d") }
  end

  describe "when value remains unchanged over multiple occurrences and time" do
    before do
      @decorator.call(deep_copy)
      @decorator.call(deep_copy)
      sleep(0.01)
      @decorator.call(deep_copy)
      sleep(0.01)
      @decorated = @decorator.call(deep_copy)
    end

    it { assert_same false, @decorated.key?("string_d") }
    it { assert_same false, @decorated.key?("string_fd") }
    it { assert_equal 0, @decorated["float_d"] }
    it { assert_in_delta 20, @decorated["float_fd"], 5 }
    it { assert_equal 0, @decorated["int_d"] }
    # On slow CIs this value tends to grow and crash
    it { assert_in_delta 20, @decorated["int_fd"], 15 }
    it { assert_predicate @decorated, :frozen? }
    it { assert_same false, @decorated.key?("float_d_d") }
  end
end
