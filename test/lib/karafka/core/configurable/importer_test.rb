# frozen_string_literal: true

describe_current do
  subject(:importer) { importer_class.new(attributes) }

  let(:attributes) { { skew_threshold: %i[ui health lags skew_threshold] } }

  # A consumer defines the root once, in its own subclass
  let(:importer_class) do
    resolver = root_resolver

    Class.new(described_class) do
      define_singleton_method(:root) { resolver.call }
    end
  end

  let(:root_resolver) { -> { config } }

  let(:config) { config_class.config }

  let(:config_class) do
    Class.new do
      extend Karafka::Core::Configurable

      setting(:per_page, default: 25)

      setting(:ui) do
        setting(:health) do
          setting(:lags) do
            setting(:skew_threshold, default: 5)
          end
        end
      end
    end
  end

  describe ".root" do
    it "expect the base class to define none" do
      assert_raises(NotImplementedError) { described_class.root }
    end

    it "expect an importer built off the base to raise on the first read" do
      this = described_class.new(attributes)
      model = Class.new { include this }

      assert_raises(NotImplementedError) { model.new.skew_threshold }
    end

    it "expect a subclass to provide it for every importer built from it" do
      assert_same config, importer_class.root
      assert_same config, importer.root
    end
  end

  describe "#included" do
    subject(:model) do
      this = importer

      Class.new { include this }
    end

    it "expect to define a reader resolving the path against the subclass root" do
      assert_equal 5, model.new.skew_threshold
    end

    it "expect to define the reader as an instance method, not a class one" do
      refute_respond_to model, :skew_threshold
      assert_respond_to model.new, :skew_threshold
    end

    it "expect to reflect the value configured before the first read" do
      config.ui.health.lags.skew_threshold = 10

      assert_equal 10, model.new.skew_threshold
    end

    context "when many attributes are imported" do
      let(:attributes) do
        {
          skew_threshold: %i[ui health lags skew_threshold],
          per_page: %i[per_page]
        }
      end

      it "expect to define a reader for each of them" do
        instance = model.new

        assert_equal 5, instance.skew_threshold
        assert_equal 25, instance.per_page
      end
    end

    context "when no attributes are given" do
      subject(:model) do
        this = importer_class.new

        Class.new { include this }
      end

      it "expect to expose the whole config root under #config" do
        assert_same config, model.new.config
      end
    end
  end

  describe "#extended" do
    subject(:model) do
      this = importer

      Class.new { extend this }
    end

    it "expect to define a class level reader resolving the path" do
      assert_equal 5, model.skew_threshold
    end

    it "expect not to define it on instances" do
      assert_respond_to model, :skew_threshold
      refute_respond_to model.new, :skew_threshold
    end
  end

  describe "memoization" do
    let(:root_resolver) do
      calls = root_calls

      lambda do
        calls << :called
        config
      end
    end

    let(:root_calls) { [] }

    context "when reading an instance level attribute many times" do
      subject(:model) do
        this = importer

        Class.new { include this }
      end

      it "expect to resolve the root only once" do
        instance = model.new
        3.times { instance.skew_threshold }

        assert_equal 1, root_calls.size
      end

      it "expect a later config change not to be visible after memoization" do
        instance = model.new

        assert_equal 5, instance.skew_threshold

        config.ui.health.lags.skew_threshold = 10

        assert_equal 5, instance.skew_threshold
      end

      it "expect to memoize per instance and not share across them" do
        first = model.new

        assert_equal 5, first.skew_threshold

        config.ui.health.lags.skew_threshold = 10

        assert_equal 10, model.new.skew_threshold
      end
    end

    context "when reading a class level attribute many times" do
      subject(:model) do
        this = importer

        Class.new { extend this }
      end

      it "expect to resolve the root only once" do
        3.times { model.skew_threshold }

        assert_equal 1, root_calls.size
      end
    end

    context "when the configured value is false" do
      subject(:model) do
        this = importer

        Class.new { include this }
      end

      before { config.ui.health.lags.skew_threshold = false }

      it "expect to re-read it on each call, as memoization is ||= based" do
        instance = model.new

        refute instance.skew_threshold
        assert_equal 1, root_calls.size

        refute instance.skew_threshold
        assert_equal 2, root_calls.size
      end
    end

    context "when the configured value is nil" do
      subject(:model) do
        this = importer

        Class.new { include this }
      end

      before { config.ui.health.lags.skew_threshold = nil }

      it "expect to re-read it on each call, as memoization is ||= based" do
        instance = model.new

        assert_nil instance.skew_threshold
        assert_nil instance.skew_threshold

        assert_equal 2, root_calls.size
      end
    end
  end

  describe "root resolution" do
    let(:root_resolver) do
      calls = root_calls

      lambda do
        calls << :called
        config
      end
    end

    let(:root_calls) { [] }

    it "expect not to resolve the root when the importer is built" do
      importer

      assert_empty root_calls
    end

    it "expect not to resolve the root when it is included" do
      this = importer
      Class.new { include this }

      assert_empty root_calls
    end

    it "expect not to resolve the root when it is extended" do
      this = importer
      Class.new { extend this }

      assert_empty root_calls
    end

    it "expect to resolve the root on the first read only" do
      this = importer
      model = Class.new { include this }

      assert_empty root_calls

      model.new.skew_threshold

      assert_equal 1, root_calls.size
    end
  end

  describe "reuse" do
    it "expect one importer to serve many targets independently" do
      this = importer
      first = Class.new { include this }
      second = Class.new { include this }

      assert_equal 5, first.new.skew_threshold
      assert_equal 5, second.new.skew_threshold
    end

    it "expect many importers off one subclass to share its root without repeating it" do
      threshold = importer_class.new(skew_threshold: %i[ui health lags skew_threshold])
      per_page = importer_class.new(per_page: %i[per_page])

      from_threshold = Class.new { include threshold }
      from_per_page = Class.new { include per_page }

      assert_equal 5, from_threshold.new.skew_threshold
      assert_equal 25, from_per_page.new.per_page
    end

    it "expect subclasses with different roots to resolve against their own" do
      other_config = Class.new do
        extend Karafka::Core::Configurable

        setting(:ui) do
          setting(:health) do
            setting(:lags) do
              setting(:skew_threshold, default: 99)
            end
          end
        end
      end.config

      other_class = Class.new(described_class) do
        define_singleton_method(:root) { other_config }
      end

      this = importer
      that = other_class.new(attributes)

      from_this = Class.new { include this }
      from_that = Class.new { include that }

      assert_equal 5, from_this.new.skew_threshold
      assert_equal 99, from_that.new.skew_threshold
    end

    it "expect a sub-subclass to inherit the root" do
      grandchild = Class.new(importer_class)

      model = Class.new { include grandchild.new(per_page: %i[per_page]) }

      assert_equal 25, model.new.per_page
    end
  end
end
