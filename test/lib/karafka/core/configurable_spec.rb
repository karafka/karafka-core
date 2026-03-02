# frozen_string_literal: true

require "test_helper"

describe_current do
  context "when we define settings on a class level" do
    subject(:configurable_class) do
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

    let(:config) { configurable_class.config }

    context "when we want to inject more settings into it" do
      before { configurable_class.config.setting(:testme, default: 7) }

      it { assert_equal 7, configurable_class.config.testme }
    end

    context "when we do not override any settings" do
      before { configurable_class.configure }

      it { assert_equal 123, config.with_default }
      it { assert_equal "name", config.nested1.nested2.name }
      it { assert_equal 6, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
      it { assert_equal 7, config.nested1.nested2.with_zero_constructor }
    end

    context "when we do override some settings" do
      before do
        configurable_class.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
      end

      it { assert_equal 7, config.with_default }
      it { assert_equal 8, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
    end

    context "when we inherit and alter settings" do
      let(:config_sub) { configurable_sub.config }

      let(:configurable_sub) do
        Class.new(configurable_class) do
          setting(:extra, default: 0)
        end
      end

      before do
        configurable_class.configure
        configurable_sub.configure
      end

      it { assert_raises(NoMethodError) { config.extra } }
      it { assert_equal 0, config_sub.extra }
      it { assert_equal 123, config.with_default }
      it { assert_equal 6, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
      it { assert_equal 123, config_sub.with_default }
      it { assert_equal 6, config_sub.nested1.nested2.leaf }
      it { assert_equal 1, config_sub.nested1.nested1 }
      it { assert_equal 5, config_sub.nested1.nested2.with_constructor }
      it { assert config_sub.nested1.nested2.ov_constructor }
    end

    context "when we inherit and change values" do
      let(:config_sub) { configurable_sub.config }

      let(:configurable_sub) do
        Class.new(configurable_class) do
          setting(:extra, default: 0)
        end
      end

      before do
        configurable_class.configure

        configurable_sub.configure do |config|
          config.with_default = 0
        end
      end

      it { assert_equal 123, config.with_default }
      it { assert_equal 0, config_sub.with_default }
    end

    context "when we run configuration once again" do
      before do
        config.configure { |node| node.with_default = 555 }
        config.configure { |node| node.nested1.nested1 = 123 }
      end

      it "expect not to update values that are set" do
        assert_equal 555, config.with_default
      end
    end

    describe "#to_h" do
      let(:expected_hash) do
        {
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
      end

      before { config.configure }

      it "expect to map with correct values" do
        assert_equal expected_hash, config.to_h
      end

      context "when casting with a dynamic attribute" do
        let(:configurable_class) do
          Class.new do
            include Karafka::Core::Configurable

            setting(:producer1, constructor: -> { 2 }, lazy: true)
            setting(:producer2, default: 1, lazy: true)
            setting(:producer3, lazy: true)
            setting(:producer4, default: 2)
          end
        end

        let(:expected_hash) do
          {
            producer1: 2,
            producer2: 1,
            producer3: nil,
            producer4: 2
          }
        end

        let(:configurable) { configurable_class.new }
        let(:config) { configurable.config }

        it { assert_equal expected_hash, config.to_h }
      end
    end

    context "when we want to merge extra config as a nested setting" do
      let(:extra) do
        Class.new do
          extend Karafka::Core::Configurable

          setting(:additional, default: 7)
        end
      end

      before do
        extra_config = extra

        configurable_class.instance_eval do
          setting(:superscope, default: extra_config.config)
        end
      end

      it { assert_equal 7, configurable_class.config.superscope.additional }

      it "expect to build correct hash when casted" do
        assert_equal 7, configurable_class.config.to_h[:superscope][:additional]
      end
    end

    context "when we define a lazy evaluated root setting" do
      let(:configurable_class) do
        default1 = default
        constructor1 = constructor

        Class.new do
          extend Karafka::Core::Configurable

          setting(
            :lazy_setting,
            default: default1,
            constructor: constructor1,
            lazy: true
          )
        end
      end

      let(:config) { configurable_class.config }
      let(:constructor) { ->(default) { default || 1 } }

      context "when default is not false nor nil" do
        let(:default) { 100 }

        it { assert_equal 100, config.lazy_setting }
      end

      context "when default is false" do
        let(:default) { false }

        it { assert_equal 1, config.lazy_setting }
      end

      context "when default is false and value is false for some time" do
        let(:attempts) { [1, 10, false, false, false] }
        let(:default) { false }
        let(:constructor) { ->(default) { default || attempts.pop } }

        it "expect to retry until non-false is present and then cache it" do
          3.times { refute config.lazy_setting }
          assert_equal 10, config.lazy_setting
          assert_equal 10, config.lazy_setting
        end
      end

      context "when constructor changes and its zero arity" do
        let(:configurable_class) do
          constructor1 = constructor

          Class.new do
            extend Karafka::Core::Configurable

            setting(
              :lazy_setting,
              constructor: constructor1,
              lazy: true
            )
          end
        end

        let(:attempts) { [1, 10, false, false, false] }
        let(:constructor) { -> { attempts.pop } }

        it "expect to retry until non-false is present and then cache it" do
          3.times { refute config.lazy_setting }
          assert_equal 10, config.lazy_setting
          assert_equal 10, config.lazy_setting
        end
      end

      context "when we want to overwrite constructed state with a different one during config" do
        let(:default) { false }
        let(:constructor) { ->(_) { false } }

        before do
          configurable_class.configure do |config|
            config.lazy_setting = 20
          end
        end

        it { assert_equal 20, config.lazy_setting }
      end
    end
  end

  context "when we define settings on an instance level" do
    let(:configurable_class) do
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

    let(:configurable) { configurable_class.new }
    let(:config) { configurable.config }

    context "when we do not override any settings" do
      before { configurable.configure }

      it { assert_equal 123, config.with_default }
      it { assert_equal 6, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
    end

    context "when we have two instances" do
      let(:configurable2) { configurable_class.new }
      let(:config2) { configurable2.config }

      before do
        configurable.configure

        configurable2.configure do |config|
          config.nested1.nested2.leaf = 100
        end
      end

      it { assert_equal 6, config.nested1.nested2.leaf }
      it { assert_equal 100, config2.nested1.nested2.leaf }
    end

    context "when we do override some settings" do
      before do
        configurable.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
      end

      it { assert_equal 7, config.with_default }
      it { assert_equal 8, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
    end

    context "when we inherit and alter settings" do
      let(:config_sub) { configurable_sub.config }

      let(:configurable_sub) do
        Class.new(configurable_class) do
          setting(:extra, default: 0)
        end.new
      end

      before do
        configurable.configure
        configurable_sub.configure
      end

      it { assert_raises(NoMethodError) { config.extra } }
      it { assert_equal 0, config_sub.extra }
      it { assert_equal 123, config.with_default }
      it { assert_equal 6, config.nested1.nested2.leaf }
      it { assert_equal 1, config.nested1.nested1 }
      it { assert_equal 5, config.nested1.nested2.with_constructor }
      it { assert config.nested1.nested2.ov_constructor }
      it { assert_equal 123, config_sub.with_default }
      it { assert_equal 6, config_sub.nested1.nested2.leaf }
      it { assert_equal 1, config_sub.nested1.nested1 }
      it { assert_equal 5, config_sub.nested1.nested2.with_constructor }
      it { assert config_sub.nested1.nested2.ov_constructor }
    end

    context "when we inherit and change values" do
      let(:config_sub) { configurable_sub.config }

      let(:configurable_sub) do
        Class.new(configurable_class) do
          setting(:extra, default: 0)
        end
      end

      before do
        configurable.configure

        configurable_sub.configure do |config|
          config.with_default = 0
        end
      end

      it { assert_equal 123, config.with_default }
      it { assert_equal 0, config_sub.with_default }
    end

    # https://github.com/karafka/karafka-core/issues/1
    context "when configurable class has a method already defined in the object class" do
      # We add method to the node to simulate this. We do not want to patch the Object class
      before do
        mod = Module.new do
          def testable
            raise
          end
        end

        Karafka::Core::Configurable::Node.include mod
      end

      let(:configurable_class) do
        Class.new do
          include Karafka::Core::Configurable

          setting(:testable, default: 123)
        end
      end

      it "expect to redefine it with the accessors" do
        instance = configurable_class.new

        instance.configure do |config|
          config.testable = 1
        end
      end
    end

    context "when we define a lazy evaluated root setting" do
      let(:configurable_class) do
        default1 = default
        constructor1 = constructor

        Class.new do
          include Karafka::Core::Configurable

          setting(
            :lazy_setting,
            default: default1,
            constructor: constructor1,
            lazy: true
          )
        end
      end

      let(:config) { configurable_class.new.tap(&:configure).config }
      let(:constructor) { ->(default) { default || 1 } }

      context "when default is not false nor nil" do
        let(:default) { 100 }

        it { assert_equal 100, config.lazy_setting }
      end

      context "when default is false" do
        let(:default) { false }

        it { assert_equal 1, config.lazy_setting }
      end

      context "when default is false and value is false for some time" do
        let(:attempts) { [1, 10, false, false, false] }
        let(:default) { false }
        let(:constructor) { ->(default) { default || attempts.pop } }

        it "expect to retry until non-false is present and then cache it" do
          3.times { refute config.lazy_setting }
          assert_equal 10, config.lazy_setting
          assert_equal 10, config.lazy_setting
        end
      end
    end
  end

  # @see https://github.com/karafka/karafka-core/issues/1
  context "when methods defined on Object" do
    before do
      Object.class_eval do
        def self.logger
          raise
        end

        def logger
          raise
        end
      end

      configurable_class.configure
      config.configure
    end

    after do
      Object.remove_method(:logger)
      Object.singleton_class.remove_method(:logger)
    end

    let(:configurable_class) do
      Class.new do
        include Karafka::Core::Configurable

        setting(:logger, default: 123)
      end
    end

    let(:configurable) { configurable_class.new }
    let(:config) { configurable.config }

    it "expect not to raise because it should redefine" do
      assert_equal 123, config.logger
    end
  end
end
