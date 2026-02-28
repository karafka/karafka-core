# frozen_string_literal: true

# Helper to build the standard configurable class used across tests
module ConfigurableClassHelper
  def build_class_level_configurable
    Class.new do
      extend Karafka::Core::Configurable

      setting(:with_default, default: 123)

      setting(:nested1) do
        setting(:nested2) do
          setting(:leaf, default: 6)
          setting(:with_constructor, default: false, constructor: ->(default) { default || 5 })
          setting(:ov_constructor, default: true, constructor: ->(default) { default || 5 })
          setting(:with_zero_constructor, constructor: -> { 7 })
          setting(:name, default: "name")
        end

        setting(:nested1, default: 1)
      end
    end
  end

  def build_instance_level_configurable
    Class.new do
      include Karafka::Core::Configurable

      setting(:with_default, default: 123)

      setting(:nested1) do
        setting(:nested2) do
          setting(:leaf, default: 6)
          setting(:with_constructor, default: false, constructor: ->(default) { default || 5 })
          setting(:ov_constructor, default: true, constructor: ->(default) { default || 5 })
        end

        setting(:nested1, default: 1)
      end
    end
  end
end

# === Class-level configurable tests ===

class ConfigurableClassLevelInjectSettingsTest < Minitest::Test
  include ConfigurableClassHelper

  def test_inject_more_settings
    configurable_class = build_class_level_configurable
    configurable_class.config.setting(:testme, default: 7)
    assert_equal 7, configurable_class.config.testme
  end
end

class ConfigurableClassLevelNoOverrideTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    @configurable_class = build_class_level_configurable
    @configurable_class.configure
    @config = @configurable_class.config
  end

  def test_with_default
    assert_equal 123, @config.with_default
  end

  def test_nested_name
    assert_equal "name", @config.nested1.nested2.name
  end

  def test_nested_leaf
    assert_equal 6, @config.nested1.nested2.leaf
  end

  def test_nested1
    assert_equal 1, @config.nested1.nested1
  end

  def test_with_constructor
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_ov_constructor
    assert_same true, @config.nested1.nested2.ov_constructor
  end

  def test_with_zero_constructor
    assert_equal 7, @config.nested1.nested2.with_zero_constructor
  end
end

class ConfigurableClassLevelOverrideTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    @configurable_class = build_class_level_configurable
    @configurable_class.configure do |config|
      config.with_default = 7
      config.nested1.nested2.leaf = 8
    end
    @config = @configurable_class.config
  end

  def test_with_default_overridden
    assert_equal 7, @config.with_default
  end

  def test_nested_leaf_overridden
    assert_equal 8, @config.nested1.nested2.leaf
  end

  def test_nested1_unchanged
    assert_equal 1, @config.nested1.nested1
  end

  def test_with_constructor_unchanged
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_ov_constructor_unchanged
    assert_same true, @config.nested1.nested2.ov_constructor
  end
end

class ConfigurableClassLevelInheritTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    @configurable_class = build_class_level_configurable
    @configurable_sub = Class.new(@configurable_class) do
      setting(:extra, default: 0)
    end

    @configurable_class.configure
    @configurable_sub.configure

    @config = @configurable_class.config
    @config_sub = @configurable_sub.config
  end

  def test_parent_does_not_have_extra
    assert_raises(NoMethodError) { @config.extra }
  end

  def test_sub_has_extra
    assert_equal 0, @config_sub.extra
  end

  def test_parent_with_default
    assert_equal 123, @config.with_default
  end

  def test_parent_nested_leaf
    assert_equal 6, @config.nested1.nested2.leaf
  end

  def test_parent_nested1
    assert_equal 1, @config.nested1.nested1
  end

  def test_parent_with_constructor
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_parent_ov_constructor
    assert_same true, @config.nested1.nested2.ov_constructor
  end

  def test_sub_with_default
    assert_equal 123, @config_sub.with_default
  end

  def test_sub_nested_leaf
    assert_equal 6, @config_sub.nested1.nested2.leaf
  end

  def test_sub_nested1
    assert_equal 1, @config_sub.nested1.nested1
  end

  def test_sub_with_constructor
    assert_equal 5, @config_sub.nested1.nested2.with_constructor
  end

  def test_sub_ov_constructor
    assert_same true, @config_sub.nested1.nested2.ov_constructor
  end
end

class ConfigurableClassLevelInheritChangeValuesTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    @configurable_class = build_class_level_configurable
    configurable_sub = Class.new(@configurable_class) do
      setting(:extra, default: 0)
    end

    @configurable_class.configure
    configurable_sub.configure do |config|
      config.with_default = 0
    end

    @config = @configurable_class.config
    @config_sub = configurable_sub.config
  end

  def test_parent_unchanged
    assert_equal 123, @config.with_default
  end

  def test_sub_changed
    assert_equal 0, @config_sub.with_default
  end
end

class ConfigurableClassLevelReconfigureTest < Minitest::Test
  include ConfigurableClassHelper

  def test_reconfigure_does_not_reset_values
    configurable_class = build_class_level_configurable
    config = configurable_class.config
    config.configure { |node| node.with_default = 555 }
    config.configure { |node| node.nested1.nested1 = 123 }
    assert_equal 555, config.with_default
  end
end

class ConfigurableClassLevelToHTest < Minitest::Test
  include ConfigurableClassHelper

  def test_to_h_maps_correct_values
    configurable_class = build_class_level_configurable
    config = configurable_class.config
    config.configure

    expected = {
      with_default: 123,
      nested1: {
        nested1: 1,
        nested2: {
          name: "name",
          leaf: 6,
          ov_constructor: true,
          with_constructor: 5,
          with_zero_constructor: 7
        }
      }
    }

    assert_equal expected, config.to_h
  end
end

class ConfigurableClassLevelToHDynamicTest < Minitest::Test
  def test_to_h_with_dynamic_attribute
    configurable_class = Class.new do
      include Karafka::Core::Configurable

      setting(:producer1, constructor: -> { 2 }, lazy: true)
      setting(:producer2, default: 1, lazy: true)
      setting(:producer3, lazy: true)
      setting(:producer4, default: 2)
    end

    config = configurable_class.new.config

    expected = {
      producer1: 2,
      producer2: 1,
      producer3: nil,
      producer4: 2
    }

    assert_equal expected, config.to_h
  end
end

class ConfigurableClassLevelMergeExtraTest < Minitest::Test
  include ConfigurableClassHelper

  def test_merge_extra_config_as_nested_setting
    configurable_class = build_class_level_configurable

    extra = Class.new do
      extend Karafka::Core::Configurable
      setting(:additional, default: 7)
    end

    extra_config = extra
    configurable_class.instance_eval do
      setting(:superscope, default: extra_config.config)
    end

    assert_equal 7, configurable_class.config.superscope.additional
  end

  def test_merge_extra_config_to_h
    configurable_class = build_class_level_configurable

    extra = Class.new do
      extend Karafka::Core::Configurable
      setting(:additional, default: 7)
    end

    extra_config = extra
    configurable_class.instance_eval do
      setting(:superscope, default: extra_config.config)
    end

    assert_equal 7, configurable_class.config.to_h[:superscope][:additional]
  end
end

class ConfigurableClassLevelLazySettingTest < Minitest::Test
  def test_lazy_with_non_false_default
    configurable_class = Class.new do
      extend Karafka::Core::Configurable
      setting(:lazy_setting, default: 100, constructor: ->(default) { default || 1 }, lazy: true)
    end

    assert_equal 100, configurable_class.config.lazy_setting
  end

  def test_lazy_with_false_default
    configurable_class = Class.new do
      extend Karafka::Core::Configurable
      setting(:lazy_setting, default: false, constructor: ->(default) { default || 1 }, lazy: true)
    end

    assert_equal 1, configurable_class.config.lazy_setting
  end

  def test_lazy_retries_until_non_false
    attempts = [1, 10, false, false, false]
    constructor = ->(default) { default || attempts.pop }

    configurable_class = Class.new do
      extend Karafka::Core::Configurable
      setting(:lazy_setting, default: false, constructor: constructor, lazy: true)
    end

    config = configurable_class.config
    3.times { assert_same false, config.lazy_setting }
    assert_equal 10, config.lazy_setting
    assert_equal 10, config.lazy_setting
  end

  def test_lazy_zero_arity_retries_until_non_false
    attempts = [1, 10, false, false, false]
    constructor = -> { attempts.pop }

    configurable_class = Class.new do
      extend Karafka::Core::Configurable
      setting(:lazy_setting, constructor: constructor, lazy: true)
    end

    config = configurable_class.config
    3.times { assert_same false, config.lazy_setting }
    assert_equal 10, config.lazy_setting
    assert_equal 10, config.lazy_setting
  end

  def test_lazy_overwrite_during_config
    configurable_class = Class.new do
      extend Karafka::Core::Configurable
      setting(:lazy_setting, default: false, constructor: ->(_) { false }, lazy: true)
    end

    configurable_class.configure do |config|
      config.lazy_setting = 20
    end

    assert_equal 20, configurable_class.config.lazy_setting
  end
end

# === Instance-level configurable tests ===

class ConfigurableInstanceLevelNoOverrideTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    configurable_class = build_instance_level_configurable
    @configurable = configurable_class.new
    @configurable.configure
    @config = @configurable.config
  end

  def test_with_default
    assert_equal 123, @config.with_default
  end

  def test_nested_leaf
    assert_equal 6, @config.nested1.nested2.leaf
  end

  def test_nested1
    assert_equal 1, @config.nested1.nested1
  end

  def test_with_constructor
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_ov_constructor
    assert_same true, @config.nested1.nested2.ov_constructor
  end
end

class ConfigurableInstanceLevelTwoInstancesTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    configurable_class = build_instance_level_configurable
    @configurable = configurable_class.new
    @configurable2 = configurable_class.new

    @configurable.configure
    @configurable2.configure do |config|
      config.nested1.nested2.leaf = 100
    end
  end

  def test_first_instance_unchanged
    assert_equal 6, @configurable.config.nested1.nested2.leaf
  end

  def test_second_instance_changed
    assert_equal 100, @configurable2.config.nested1.nested2.leaf
  end
end

class ConfigurableInstanceLevelOverrideTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    configurable_class = build_instance_level_configurable
    @configurable = configurable_class.new
    @configurable.configure do |config|
      config.with_default = 7
      config.nested1.nested2.leaf = 8
    end
    @config = @configurable.config
  end

  def test_with_default_overridden
    assert_equal 7, @config.with_default
  end

  def test_nested_leaf_overridden
    assert_equal 8, @config.nested1.nested2.leaf
  end

  def test_nested1_unchanged
    assert_equal 1, @config.nested1.nested1
  end

  def test_with_constructor
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_ov_constructor
    assert_same true, @config.nested1.nested2.ov_constructor
  end
end

class ConfigurableInstanceLevelInheritTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    configurable_class = build_instance_level_configurable
    @configurable = configurable_class.new

    configurable_sub_class = Class.new(configurable_class) do
      setting(:extra, default: 0)
    end
    @configurable_sub = configurable_sub_class.new

    @configurable.configure
    @configurable_sub.configure

    @config = @configurable.config
    @config_sub = @configurable_sub.config
  end

  def test_parent_does_not_have_extra
    assert_raises(NoMethodError) { @config.extra }
  end

  def test_sub_has_extra
    assert_equal 0, @config_sub.extra
  end

  def test_parent_with_default
    assert_equal 123, @config.with_default
  end

  def test_parent_nested_leaf
    assert_equal 6, @config.nested1.nested2.leaf
  end

  def test_parent_nested1
    assert_equal 1, @config.nested1.nested1
  end

  def test_parent_with_constructor
    assert_equal 5, @config.nested1.nested2.with_constructor
  end

  def test_parent_ov_constructor
    assert_same true, @config.nested1.nested2.ov_constructor
  end

  def test_sub_with_default
    assert_equal 123, @config_sub.with_default
  end

  def test_sub_nested_leaf
    assert_equal 6, @config_sub.nested1.nested2.leaf
  end

  def test_sub_nested1
    assert_equal 1, @config_sub.nested1.nested1
  end

  def test_sub_with_constructor
    assert_equal 5, @config_sub.nested1.nested2.with_constructor
  end

  def test_sub_ov_constructor
    assert_same true, @config_sub.nested1.nested2.ov_constructor
  end
end

class ConfigurableInstanceLevelInheritChangeValuesTest < Minitest::Test
  include ConfigurableClassHelper

  def setup
    configurable_class = build_instance_level_configurable
    @configurable = configurable_class.new
    @configurable.configure

    configurable_sub_class = Class.new(configurable_class) do
      setting(:extra, default: 0)
    end

    configurable_sub_class.configure do |config|
      config.with_default = 0
    end

    @config = @configurable.config
    @config_sub = configurable_sub_class.config
  end

  def test_parent_unchanged
    assert_equal 123, @config.with_default
  end

  def test_sub_changed
    assert_equal 0, @config_sub.with_default
  end
end

class ConfigurableInstanceLevelExistingMethodTest < Minitest::Test
  def test_redefines_existing_method_with_accessors
    mod = Module.new do
      def testable
        raise
      end
    end

    Karafka::Core::Configurable::Node.include mod

    configurable_class = Class.new do
      include Karafka::Core::Configurable
      setting(:testable, default: 123)
    end

    instance = configurable_class.new
    instance.configure do |config|
      config.testable = 1
    end
  end
end

class ConfigurableInstanceLevelLazySettingTest < Minitest::Test
  def test_lazy_with_non_false_default
    configurable_class = Class.new do
      include Karafka::Core::Configurable
      setting(:lazy_setting, default: 100, constructor: ->(default) { default || 1 }, lazy: true)
    end

    config = configurable_class.new.tap(&:configure).config
    assert_equal 100, config.lazy_setting
  end

  def test_lazy_with_false_default
    configurable_class = Class.new do
      include Karafka::Core::Configurable
      setting(:lazy_setting, default: false, constructor: ->(default) { default || 1 }, lazy: true)
    end

    config = configurable_class.new.tap(&:configure).config
    assert_equal 1, config.lazy_setting
  end

  def test_lazy_retries_until_non_false
    attempts = [1, 10, false, false, false]
    constructor = ->(default) { default || attempts.pop }

    configurable_class = Class.new do
      include Karafka::Core::Configurable
      setting(:lazy_setting, default: false, constructor: constructor, lazy: true)
    end

    config = configurable_class.new.tap(&:configure).config
    3.times { assert_same false, config.lazy_setting }
    assert_equal 10, config.lazy_setting
    assert_equal 10, config.lazy_setting
  end
end

class ConfigurableObjectMethodTest < Minitest::Test
  def test_redefines_object_method
    Object.class_eval do
      def self.logger
        raise
      end

      def logger
        raise
      end
    end

    configurable_class = Class.new do
      include Karafka::Core::Configurable
      setting(:logger, default: 123)
    end

    configurable = configurable_class.new
    configurable_class.configure
    configurable.config.configure

    assert_equal 123, configurable.config.logger
  ensure
    Object.remove_method(:logger)
    Object.singleton_class.remove_method(:logger)
  end
end
