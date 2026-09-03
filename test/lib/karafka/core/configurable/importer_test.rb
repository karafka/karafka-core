# frozen_string_literal: true

describe_current do
  subject(:importer) { described_class.new(attributes, root: root) }

  let(:attributes) { { skew_threshold: %i[ui health lags skew_threshold] } }
  let(:root) { -> { config } }

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

  describe "#included" do
    subject(:model) do
      this = importer

      Class.new { include this }
    end

    it "expect to define a reader resolving the path against the supplied root" do
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
        this = described_class.new(root: root)

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
    let(:root) do
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
    let(:root) do
      calls = root_calls

      lambda do
        calls << :called
        config
      end
    end

    let(:root_calls) { [] }

    it "expect not to call the root when the importer is built" do
      importer

      assert_empty root_calls
    end

    it "expect not to call the root when it is included" do
      this = importer
      Class.new { include this }

      assert_empty root_calls
    end

    it "expect not to call the root when it is extended" do
      this = importer
      Class.new { extend this }

      assert_empty root_calls
    end

    it "expect to call the root on the first read only" do
      this = importer
      model = Class.new { include this }

      assert_empty root_calls

      model.new.skew_threshold

      assert_equal 1, root_calls.size
    end
  end

  describe "reuse across targets and roots" do
    it "expect one importer to serve many targets independently" do
      this = importer
      first = Class.new { include this }
      second = Class.new { include this }

      assert_equal 5, first.new.skew_threshold
      assert_equal 5, second.new.skew_threshold
    end

    it "expect importers with different roots to resolve against their own" do
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

      this = importer
      that = described_class.new(attributes, root: -> { other_config })

      from_this = Class.new { include this }
      from_that = Class.new { include that }

      assert_equal 5, from_this.new.skew_threshold
      assert_equal 99, from_that.new.skew_threshold
    end
  end
end
