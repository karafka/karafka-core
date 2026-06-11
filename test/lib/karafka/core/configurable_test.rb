# frozen_string_literal: true

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

    describe "#register" do
      let(:node) { configurable_class.config }

      context "when registering a new key-value pair" do
        before { node.register(:my_cluster, { "bootstrap.servers": "kafka:9092" }) }

        it "makes the value readable via accessor" do
          assert_equal({ "bootstrap.servers": "kafka:9092" }, node.my_cluster)
        end

        it "makes the value writable via accessor" do
          node.my_cluster = { "bootstrap.servers": "other:9092" }

          assert_equal({ "bootstrap.servers": "other:9092" }, node.my_cluster)
        end

        it "includes the registered key in to_h" do
          assert node.to_h.key?(:my_cluster)
          assert_equal({ "bootstrap.servers": "kafka:9092" }, node.to_h[:my_cluster])
        end

        it "carries the registered key through deep_dup" do
          dupped = node.deep_dup
          dupped.configure

          assert_equal({ "bootstrap.servers": "kafka:9092" }, dupped.my_cluster)
        end
      end

      context "when registering a string name" do
        before { node.register("analytics", 42) }

        it "coerces the name to a symbol" do
          assert_equal 42, node.analytics
        end
      end

      context "when registering multiple keys" do
        before do
          node.register(:cluster_a, "a:9092")
          node.register(:cluster_b, "b:9092")
        end

        it "stores all keys independently" do
          assert_equal "a:9092", node.cluster_a
          assert_equal "b:9092", node.cluster_b
        end

        it "includes all keys in to_h" do
          assert_equal "a:9092", node.to_h[:cluster_a]
          assert_equal "b:9092", node.to_h[:cluster_b]
        end
      end

      context "when registering a duplicate name" do
        before { node.register(:taken, "first") }

        it "raises ArgumentError" do
          assert_raises(ArgumentError) { node.register(:taken, "second") }
        end

        it "does not overwrite the original value" do
          begin
            node.register(:taken, "second")
          rescue ArgumentError
            nil
          end

          assert_equal "first", node.taken
        end
      end

      context "when the registered value is nil" do
        before { node.register(:nullable, nil) }

        it "stores and returns nil" do
          assert_nil node.nullable
        end

        it "includes the key in to_h" do
          assert node.to_h.key?(:nullable)
        end
      end

      context "when registering a name that cannot back an instance variable" do
        before { node.register(:"my-cluster", "dashed:9092") }

        it "makes the value readable via accessor" do
          assert_equal "dashed:9092", node.public_send(:"my-cluster")
        end

        it "makes the value writable via accessor" do
          node.public_send(:"my-cluster=", "changed:9092")

          assert_equal "changed:9092", node.public_send(:"my-cluster")
        end

        it "includes the registered key in to_h" do
          assert_equal "dashed:9092", node.to_h[:"my-cluster"]
        end

        it "carries the registered key through deep_dup" do
          dupped = node.deep_dup
          dupped.configure

          assert_equal "dashed:9092", dupped.public_send(:"my-cluster")
        end
      end

      context "when registering on a nested node" do
        before { configurable_class.config.nested1.register(:extra, "nested-value") }

        it "makes the value readable on the nested node" do
          assert_equal "nested-value", configurable_class.config.nested1.extra
        end

        it "includes it in the nested node's to_h" do
          assert_equal "nested-value", configurable_class.config.nested1.to_h[:extra]
        end
      end
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
