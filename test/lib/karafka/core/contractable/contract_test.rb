# frozen_string_literal: true

class KarafkaCoreContractableContractValidateTest < Minitest::Test
  def validator_class
    @validator_class ||= Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("config")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
      optional(:name) { |name| name == "name" }
    end
  end

  def test_validate_valid_data
    validator_class.new.validate!({ id: "1" }, ArgumentError)
  end

  def test_validate_invalid_required
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1 }, ArgumentError)
    end
  end

  def test_validate_invalid_optional_test
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, test: Time.now }, ArgumentError)
    end
  end

  def test_validate_invalid_optional_name
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, name: Time.now }, ArgumentError)
    end
  end

  def test_validate_valid_optional_name
    validator_class.new.validate!({ id: "1", name: "name" }, ArgumentError)
  end

  def test_validate_invalid_optional_nil
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, test: nil }, ArgumentError)
    end
  end
end

class KarafkaCoreContractableContractValidateWithScopeTest < Minitest::Test
  def validator_class
    @validator_class ||= Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("config")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
      optional(:name) { |name| name == "name" }
    end
  end

  def scope
    @scope ||= [rand.to_s, rand.to_s]
  end

  def test_validate_valid_data_with_scope
    validator_class.new.validate!({ id: "1" }, ArgumentError, scope: scope)
  end

  def test_validate_invalid_required_with_scope
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1 }, ArgumentError, scope: scope)
    end
  end

  def test_validate_invalid_optional_test_with_scope
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, test: Time.now }, ArgumentError, scope: scope)
    end
  end

  def test_validate_invalid_optional_name_with_scope
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, name: Time.now }, ArgumentError, scope: scope)
    end
  end

  def test_validate_valid_optional_name_with_scope
    validator_class.new.validate!({ id: "1", name: "name" }, ArgumentError, scope: scope)
  end

  def test_validate_invalid_optional_nil_with_scope
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1, test: nil }, ArgumentError, scope: scope)
    end
  end
end

class KarafkaCoreContractableContractErrorKeyNotAvailableTest < Minitest::Test
  def test_validate_raises_key_error_for_missing_error_key
    validator_class = Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("config")
      end

      required(:na_id) { |id| id.is_a?(String) }
    end

    assert_raises(KeyError) do
      validator_class.new.validate!({ na_id: 1 }, ArgumentError)
    end
  end
end

class KarafkaCoreContractableContractCallTest < Minitest::Test
  def validator_class
    @validator_class ||= Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("config")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
      optional(:name) { |name| name == "name" }
    end
  end

  def test_call_valid_data_has_no_errors
    scope = [rand.to_s, rand.to_s]
    result = validator_class.new.call({ id: "1" }, scope: scope)
    assert_equal({}, result.errors)
  end

  def test_call_invalid_data_has_scoped_error_key
    scope = [rand.to_s, rand.to_s]
    result = validator_class.new.call({ id: 1 }, scope: scope)
    assert_includes result.errors.keys, :"#{scope.join(".")}.id"
  end
end

class KarafkaCoreContractableContractNestedValuesTest < Minitest::Test
  def validator_class
    @validator_class ||= Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      nested(:nested) do
        required(:id) { |id| id.is_a?(String) }
        optional(:id2) { |id| id.is_a?(String) }
      end
    end
  end

  def test_valid_without_optional
    validator_class.new.validate!({ nested: { id: "1" } }, ArgumentError)
  end

  def test_valid_with_optional
    validator_class.new.validate!({ nested: { id: "1", id2: "2" } }, ArgumentError)
  end

  def test_invalid_optional
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ nested: { id: "1", id2: 2 } }, ArgumentError)
    end
  end

  def test_invalid_missing_nested
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1 }, ArgumentError)
    end
  end
end

class KarafkaCoreContractableContractVirtualTest < Minitest::Test
  def test_virtual_error_raises
    validator_class = Class.new(Karafka::Core::Contractable::Contract) do
      virtual do
        [[%i[id], "String error"]]
      end
    end

    assert_raises(ArgumentError) do
      validator_class.new.validate!({ nested: { id: "1" } }, ArgumentError)
    end
  end
end

class KarafkaCoreContractableContractMultipleNestingsTest < Minitest::Test
  def validator_class
    @validator_class ||= Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("config")
      end

      nested(:a) do
        nested(:b) do
          nested(:c) do
            required(:id) { |id| id.is_a?(String) }
          end
        end
      end
    end
  end

  def test_valid_deeply_nested
    validator_class.new.validate!({ a: { b: { c: { id: "1" } } } }, ArgumentError)
  end

  def test_invalid_deeply_nested
    assert_raises(ArgumentError) do
      validator_class.new.validate!({ id: 1 }, ArgumentError)
    end
  end
end
