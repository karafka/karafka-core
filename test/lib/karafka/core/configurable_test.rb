# frozen_string_literal: true

describe_current do
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

  describe "when we define settings on a class level" do
    describe "when we want to inject more settings into it" do
      it "expect to accept new settings" do
        configurable_class = build_class_level_configurable
        configurable_class.config.setting(:testme, default: 7)

        assert_equal 7, configurable_class.config.testme
      end
    end

    describe "when we do not override any settings" do
      before do
        @configurable_class = build_class_level_configurable
        @configurable_class.configure
        @config = @configurable_class.config
      end

      it { assert_equal 123, @config.with_default }
      it { assert_equal "name", @config.nested1.nested2.name }
      it { assert_equal 6, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
      it { assert_equal 7, @config.nested1.nested2.with_zero_constructor }
    end

    describe "when we do override some settings" do
      before do
        @configurable_class = build_class_level_configurable
        @configurable_class.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
        @config = @configurable_class.config
      end

      it { assert_equal 7, @config.with_default }
      it { assert_equal 8, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
    end

    describe "when we inherit and alter settings" do
      before do
        @configurable_class = build_class_level_configurable
        @configurable_sub = Class.new(@configurable_class) do
          setting(:extra, default: 0)
        end

        @configurable_class.configure
        @configurable_sub.configure

        @config = @configurable_class.config
        @config_sub = @configurable_sub.config
      end

      it { assert_raises(NoMethodError) { @config.extra } }
      it { assert_equal 0, @config_sub.extra }
      it { assert_equal 123, @config.with_default }
      it { assert_equal 6, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
      it { assert_equal 123, @config_sub.with_default }
      it { assert_equal 6, @config_sub.nested1.nested2.leaf }
      it { assert_equal 1, @config_sub.nested1.nested1 }
      it { assert_equal 5, @config_sub.nested1.nested2.with_constructor }
      it { assert_same true, @config_sub.nested1.nested2.ov_constructor }
    end

    describe "when we inherit and change values" do
      before do
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

      it { assert_equal 123, @config.with_default }
      it { assert_equal 0, @config_sub.with_default }
    end

    describe "when we run configuration once again" do
      it "expect not to update values that are set" do
        configurable_class = build_class_level_configurable
        config = configurable_class.config
        config.configure { |node| node.with_default = 555 }
        config.configure { |node| node.nested1.nested1 = 123 }

        assert_equal 555, config.with_default
      end
    end

    describe "#to_h" do
      it "expect to map with correct values" do
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

      describe "when casting with a dynamic attribute" do
        it "expect to map correctly" do
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
    end

    describe "when we want to merge extra config as a nested setting" do
      before do
        @configurable_class = build_class_level_configurable

        extra = Class.new do
          extend Karafka::Core::Configurable

          setting(:additional, default: 7)
        end

        extra_config = extra
        @configurable_class.instance_eval do
          setting(:superscope, default: extra_config.config)
        end
      end

      it { assert_equal 7, @configurable_class.config.superscope.additional }

      it "expect to build correct hash when casted" do
        assert_equal 7, @configurable_class.config.to_h[:superscope][:additional]
      end
    end

    describe "when we define a lazy evaluated root setting" do
      describe "when default is not false nor nil" do
        it "expect to return default" do
          configurable_class = Class.new do
            extend Karafka::Core::Configurable

            setting(:lazy_setting, default: 100, constructor: ->(default) { default || 1 }, lazy: true)
          end

          assert_equal 100, configurable_class.config.lazy_setting
        end
      end

      describe "when default is false" do
        it "expect to return constructed value" do
          configurable_class = Class.new do
            extend Karafka::Core::Configurable

            setting(:lazy_setting, default: false, constructor: ->(default) { default || 1 }, lazy: true)
          end

          assert_equal 1, configurable_class.config.lazy_setting
        end
      end

      describe "when default is false and value is false for some time" do
        it "expect to retry until non-false is present and then cache it" do
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
      end

      describe "when constructor changes and its zero arity" do
        it "expect to retry until non-false is present and then cache it" do
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
      end

      describe "when we want to overwrite constructed state with a different one during config" do
        it "expect to use the overwritten value" do
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
    end
  end

  describe "when we define settings on an instance level" do
    describe "when we do not override any settings" do
      before do
        configurable_class = build_instance_level_configurable
        @configurable = configurable_class.new
        @configurable.configure
        @config = @configurable.config
      end

      it { assert_equal 123, @config.with_default }
      it { assert_equal 6, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
    end

    describe "when we have two instances" do
      before do
        configurable_class = build_instance_level_configurable
        @configurable = configurable_class.new
        @configurable2 = configurable_class.new

        @configurable.configure
        @configurable2.configure do |config|
          config.nested1.nested2.leaf = 100
        end
      end

      it { assert_equal 6, @configurable.config.nested1.nested2.leaf }
      it { assert_equal 100, @configurable2.config.nested1.nested2.leaf }
    end

    describe "when we do override some settings" do
      before do
        configurable_class = build_instance_level_configurable
        @configurable = configurable_class.new
        @configurable.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
        @config = @configurable.config
      end

      it { assert_equal 7, @config.with_default }
      it { assert_equal 8, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
    end

    describe "when we inherit and alter settings" do
      before do
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

      it { assert_raises(NoMethodError) { @config.extra } }
      it { assert_equal 0, @config_sub.extra }
      it { assert_equal 123, @config.with_default }
      it { assert_equal 6, @config.nested1.nested2.leaf }
      it { assert_equal 1, @config.nested1.nested1 }
      it { assert_equal 5, @config.nested1.nested2.with_constructor }
      it { assert_same true, @config.nested1.nested2.ov_constructor }
      it { assert_equal 123, @config_sub.with_default }
      it { assert_equal 6, @config_sub.nested1.nested2.leaf }
      it { assert_equal 1, @config_sub.nested1.nested1 }
      it { assert_equal 5, @config_sub.nested1.nested2.with_constructor }
      it { assert_same true, @config_sub.nested1.nested2.ov_constructor }
    end

    describe "when we inherit and change values" do
      before do
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

      it { assert_equal 123, @config.with_default }
      it { assert_equal 0, @config_sub.with_default }
    end

    describe "when configurable class has a method already defined in the object class" do
      it "expect to redefine it with the accessors" do
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

    describe "when we define a lazy evaluated root setting" do
      describe "when default is not false nor nil" do
        it "expect to return default" do
          configurable_class = Class.new do
            include Karafka::Core::Configurable

            setting(:lazy_setting, default: 100, constructor: ->(default) { default || 1 }, lazy: true)
          end

          config = configurable_class.new.tap(&:configure).config

          assert_equal 100, config.lazy_setting
        end
      end

      describe "when default is false" do
        it "expect to return constructed value" do
          configurable_class = Class.new do
            include Karafka::Core::Configurable

            setting(:lazy_setting, default: false, constructor: ->(default) { default || 1 }, lazy: true)
          end

          config = configurable_class.new.tap(&:configure).config

          assert_equal 1, config.lazy_setting
        end
      end

      describe "when default is false and value is false for some time" do
        it "expect to retry until non-false is present and then cache it" do
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
    end
  end

  describe "when methods defined on Object" do
    it "expect not to raise because it should redefine" do
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
end
