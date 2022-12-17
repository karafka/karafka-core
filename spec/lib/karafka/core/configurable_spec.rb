# frozen_string_literal: true

RSpec.describe_current do
  context 'when we define settings on a class level' do
    subject(:configurable_class) do
      Class.new do
        extend Karafka::Core::Configurable

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

    let(:config) { configurable_class.config }

    context 'when we want to inject more settings into it' do
      before { configurable_class.config.setting(:testme, default: 7) }

      it { expect(configurable_class.config.testme).to eq(7) }
    end

    context 'when we do not override any settings' do
      before { configurable_class.configure }

      it { expect(config.with_default).to eq(123) }
      it { expect(config.nested1.nested2.leaf).to eq(6) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we do override some settings' do
      before do
        configurable_class.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
      end

      it { expect(config.with_default).to eq(7) }
      it { expect(config.nested1.nested2.leaf).to eq(8) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we inherit and alter settings' do
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

      it { expect { config.extra }.to raise_error(NoMethodError) }
      it { expect(config_sub.extra).to eq(0) }
      it { expect(config.with_default).to eq(123) }
      it { expect(config.nested1.nested2.leaf).to eq(6) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
      it { expect(config_sub.with_default).to eq(123) }
      it { expect(config_sub.nested1.nested2.leaf).to eq(6) }
      it { expect(config_sub.nested1.nested1).to eq(1) }
      it { expect(config_sub.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config_sub.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we inherit and change values' do
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

      it { expect(config.with_default).to eq(123) }
      it { expect(config_sub.with_default).to eq(0) }
    end

    context 'when we run configuration once again' do
      before do
        config.configure { |node| node.with_default = 555 }
        config.configure { |node| node.nested1.nested1 = 123 }
      end

      it 'expect not to update values that are set' do
        expect(config.with_default).to eq(555)
      end
    end

    describe '#to_h' do
      before { config.configure }

      it 'expect to map with correct values' do
        expect(config.to_h).to eq(
          with_default: 123,
          nested1: { nested1: 1, nested2: { leaf: 6, ov_constructor: true, with_constructor: 5 } }
        )
      end
    end

    context 'when we want to merge extra config as a nested setting' do
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

      it { expect(configurable_class.config.superscope.additional).to eq(7) }

      it 'expect to build correct hash when casted' do
        expect(configurable_class.config.to_h[:superscope][:additional]).to eq(7)
      end
    end
  end

  context 'when we define settings on an instance level' do
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

    context 'when we do not override any settings' do
      before { configurable.configure }

      it { expect(config.with_default).to eq(123) }
      it { expect(config.nested1.nested2.leaf).to eq(6) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we have two instances' do
      let(:configurable2) { configurable_class.new }
      let(:config2) { configurable2.config }

      before do
        configurable.configure

        configurable2.configure do |config|
          config.nested1.nested2.leaf = 100
        end
      end

      it { expect(config.nested1.nested2.leaf).to eq(6) }
      it { expect(config2.nested1.nested2.leaf).to eq(100) }
    end

    context 'when we do override some settings' do
      before do
        configurable.configure do |config|
          config.with_default = 7
          config.nested1.nested2.leaf = 8
        end
      end

      it { expect(config.with_default).to eq(7) }
      it { expect(config.nested1.nested2.leaf).to eq(8) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we inherit and alter settings' do
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

      it { expect { config.extra }.to raise_error(NoMethodError) }
      it { expect(config_sub.extra).to eq(0) }
      it { expect(config.with_default).to eq(123) }
      it { expect(config.nested1.nested2.leaf).to eq(6) }
      it { expect(config.nested1.nested1).to eq(1) }
      it { expect(config.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config.nested1.nested2.ov_constructor).to eq(true) }
      it { expect(config_sub.with_default).to eq(123) }
      it { expect(config_sub.nested1.nested2.leaf).to eq(6) }
      it { expect(config_sub.nested1.nested1).to eq(1) }
      it { expect(config_sub.nested1.nested2.with_constructor).to eq(5) }
      it { expect(config_sub.nested1.nested2.ov_constructor).to eq(true) }
    end

    context 'when we inherit and change values' do
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

      it { expect(config.with_default).to eq(123) }
      it { expect(config_sub.with_default).to eq(0) }
    end

    # https://github.com/karafka/karafka-core/issues/1
    context 'when configurable class has a method already defined in the object class' do
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

      it 'expect to redefine it with the accessors' do
        instance = configurable_class.new

        instance.configure do |config|
          config.testable = 1
        end
      end
    end
  end
end
