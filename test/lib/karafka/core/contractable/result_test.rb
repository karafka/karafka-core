# frozen_string_literal: true

class KarafkaCoreContractableResultNoErrorsTest < Minitest::Test
  def setup
    contract_class = Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
    end

    @result = contract_class.new.call({ id: "123", test: 5 })
  end

  def test_success
    assert_same true, @result.success?
  end

  def test_no_errors
    assert_empty @result.errors
  end
end

class KarafkaCoreContractableResultWithErrorsTest < Minitest::Test
  def setup
    contract_class = Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
    end

    @result = contract_class.new.call({ id: 123, test: 4 })
  end

  def test_not_success
    assert_same false, @result.success?
  end

  def test_maps_errors_to_messages
    assert_equal(
      { id: "needs to be a String", test: "needs to be 5" },
      @result.errors
    )
  end
end

class KarafkaCoreContractableResultWithNestedErrorsTest < Minitest::Test
  def setup
    contract_class = Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      nested(:details) do
        required(:id) { |id| id.is_a?(String) }
      end
    end

    @result = contract_class.new.call({ details: { id: 123 } })
  end

  def test_not_success
    assert_same false, @result.success?
  end

  def test_maps_nested_errors_with_dot_notation
    assert_equal(
      { "details.id": "needs to be a String" },
      @result.errors
    )
  end
end

class KarafkaCoreContractableResultUnmappedErrorTest < Minitest::Test
  def setup
    contract_class = Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      required(:id) { |id| id.is_a?(String) }
    end

    @result = contract_class.new.call({ id: 123 })
  end

  def test_not_success
    assert_same false, @result.success?
  end

  def test_falls_back_to_generic_error
    assert_equal(
      { id: "needs to be a String" },
      @result.errors
    )
  end
end
