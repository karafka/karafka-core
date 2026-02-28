# frozen_string_literal: true

class KarafkaCoreStatisticsDecoratorFirstEmitTest < Minitest::Test
  def setup
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

  def test_string_value
    decorated = @decorator.call(emited_stats1)
    assert_equal "value1", decorated["string"]
  end

  def test_no_string_delta
    decorated = @decorator.call(emited_stats1)
    assert_same false, decorated.key?("string_d")
  end

  def test_float_delta_is_zero
    decorated = @decorator.call(emited_stats1)
    assert_equal 0, decorated["float_d"]
  end

  def test_int_delta_is_zero
    decorated = @decorator.call(emited_stats1)
    assert_equal 0, decorated["int_d"]
  end

  def test_nested_delta_is_zero
    decorated = @decorator.call(emited_stats1)
    assert_equal 0, decorated.dig(*@broker_scope)["txbytes_d"]
  end

  def test_frozen
    decorated = @decorator.call(emited_stats1)
    assert_predicate decorated, :frozen?
  end
end

class KarafkaCoreStatisticsDecoratorSecondEmitTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
    @broker_scope = %w[nested brokers localhost:9092/2]
  end

  def emited_stats1
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }
    }
  end

  def emited_stats2
    {
      "string" => "value2", "float" => 10.8, "int" => 130,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 153 } } }
    }
  end

  def decorated
    @decorator.call(emited_stats1)
    @decorator.call(emited_stats2)
  end

  def test_string_value
    assert_equal "value2", decorated["string"]
  end

  def test_no_string_delta
    assert_same false, decorated.key?("string_d")
  end

  def test_float_delta
    assert_equal 0.4, decorated["float_d"].round(10)
  end

  def test_int_delta
    assert_equal 18, decorated["int_d"]
  end

  def test_nested_delta
    assert_equal 30, decorated.dig(*@broker_scope)["txbytes_d"]
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end
end

class KarafkaCoreStatisticsDecoratorThirdEmitTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
    @broker_scope = %w[nested brokers localhost:9092/2]
  end

  def emited_stats1
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }
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

  def decorated
    @decorator.call(emited_stats1)
    @decorator.call(emited_stats2)
    @decorator.call(emited_stats3)
  end

  def test_string_value
    assert_equal "value3", decorated["string"]
  end

  def test_no_string_d
    assert_same false, decorated.key?("string_d")
  end

  def test_no_string_fd
    assert_same false, decorated.key?("string_fd")
  end

  def test_float_delta
    assert_equal 1.0, decorated["float_d"].round(10)
  end

  def test_float_freeze_duration
    assert_in_delta 0, decorated["float_fd"], 5
  end

  def test_int_delta
    assert_equal(-120, decorated["int_d"])
  end

  def test_int_freeze_duration
    assert_in_delta 0, decorated["int_fd"], 5
  end

  def test_nested_txbytes_delta
    assert_equal(-151, decorated.dig(*@broker_scope)["txbytes_d"])
  end

  def test_nested_txbytes_freeze_duration
    assert_in_delta 0, decorated.dig(*@broker_scope)["txbytes_fd"], 5
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end

  def test_no_float_d_d
    assert_same false, decorated.key?("float_d_d")
  end
end

class KarafkaCoreStatisticsDecoratorBrokerNoLongerPresentTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
    @broker_scope = %w[nested brokers localhost:9092/2]
  end

  def emited_stats1
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }
    }
  end

  def emited_stats2
    {
      "string" => "value2", "float" => 10.8, "int" => 130,
      "nested" => {}
    }
  end

  def decorated
    @decorator.call(emited_stats1)
    @decorator.call(emited_stats2)
  end

  def test_string_value
    assert_equal "value2", decorated["string"]
  end

  def test_no_string_d
    assert_same false, decorated.key?("string_d")
  end

  def test_no_string_fd
    assert_same false, decorated.key?("string_fd")
  end

  def test_float_delta
    assert_equal 0.4, decorated["float_d"].round(10)
  end

  def test_float_freeze_duration
    assert_in_delta 0, decorated["float_fd"], 5
  end

  def test_int_delta
    assert_equal 18, decorated["int_d"]
  end

  def test_int_freeze_duration
    assert_in_delta 0, decorated["int_fd"], 5
  end

  def test_nested_empty
    assert_equal({}, decorated["nested"])
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end

  def test_no_float_d_d
    assert_same false, decorated.key?("float_d_d")
  end
end

class KarafkaCoreStatisticsDecoratorBrokerIntroducedLaterTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
    @broker_scope = %w[nested brokers localhost:9092/2]
  end

  def emited_stats1
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => {}
    }
  end

  def emited_stats2
    {
      "string" => "value2", "float" => 10.8, "int" => 130,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 153 } } }
    }
  end

  def decorated
    @decorator.call(emited_stats1)
    @decorator.call(emited_stats2)
  end

  def test_string_value
    assert_equal "value2", decorated["string"]
  end

  def test_no_string_d
    assert_same false, decorated.key?("string_d")
  end

  def test_float_delta
    assert_equal 0.4, decorated["float_d"].round(10)
  end

  def test_float_freeze_duration
    assert_in_delta 0, decorated["float_fd"], 5
  end

  def test_int_delta
    assert_equal 18, decorated["int_d"]
  end

  def test_int_freeze_duration
    assert_in_delta 0, decorated["int_fd"], 5
  end

  def test_nested_txbytes_delta
    assert_equal 0, decorated.dig(*@broker_scope)["txbytes_d"]
  end

  def test_nested_txbytes_freeze_duration
    assert_in_delta 0, decorated.dig(*@broker_scope)["txbytes_fd"], 5
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end

  def test_no_float_d_d
    assert_same false, decorated.key?("float_d_d")
  end
end

class KarafkaCoreStatisticsDecoratorUnchangedOverTimeTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
  end

  def base_stats
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }
    }
  end

  def deep_copy
    Marshal.load(Marshal.dump(base_stats))
  end

  def decorated
    @decorator.call(deep_copy)
    @decorator.call(deep_copy)
    sleep(0.01)
    @decorator.call(deep_copy)
  end

  def test_no_string_d
    assert_same false, decorated.key?("string_d")
  end

  def test_no_string_fd
    assert_same false, decorated.key?("string_fd")
  end

  def test_float_delta_zero
    assert_equal 0, decorated["float_d"]
  end

  def test_float_freeze_duration
    assert_in_delta 10, decorated["float_fd"], 5
  end

  def test_int_delta_zero
    assert_equal 0, decorated["int_d"]
  end

  def test_int_freeze_duration
    assert_in_delta 10, decorated["int_fd"], 5
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end

  def test_no_float_d_d
    assert_same false, decorated.key?("float_d_d")
  end
end

class KarafkaCoreStatisticsDecoratorUnchangedMultipleOccurrencesTest < Minitest::Test
  def setup
    @decorator = Karafka::Core::Monitoring::StatisticsDecorator.new
  end

  def base_stats
    {
      "string" => "value1", "float" => 10.4, "int" => 112,
      "nested" => { "brokers" => { "localhost:9092/2" => { "txbytes" => 123 } } }
    }
  end

  def deep_copy
    Marshal.load(Marshal.dump(base_stats))
  end

  def decorated
    @decorator.call(deep_copy)
    @decorator.call(deep_copy)
    sleep(0.01)
    @decorator.call(deep_copy)
    sleep(0.01)
    @decorator.call(deep_copy)
  end

  def test_no_string_d
    assert_same false, decorated.key?("string_d")
  end

  def test_no_string_fd
    assert_same false, decorated.key?("string_fd")
  end

  def test_float_delta_zero
    assert_equal 0, decorated["float_d"]
  end

  def test_float_freeze_duration
    assert_in_delta 20, decorated["float_fd"], 5
  end

  def test_int_delta_zero
    assert_equal 0, decorated["int_d"]
  end

  def test_int_freeze_duration
    assert_in_delta 20, decorated["int_fd"], 15
  end

  def test_frozen
    assert_predicate decorated, :frozen?
  end

  def test_no_float_d_d
    assert_same false, decorated.key?("float_d_d")
  end
end
