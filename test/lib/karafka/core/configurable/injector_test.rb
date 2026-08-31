# frozen_string_literal: true

describe_current do
  describe ".defaults" do
    it "expect the base to define no defaults" do
      assert_equal({}, described_class.defaults)
    end

    it "expect to return the same immutable empty defaults each call (no per-call allocation)" do
      assert_same described_class.defaults, described_class.defaults
      assert_predicate described_class.defaults, :frozen?
    end
  end

  describe ".call" do
    context "when the injector defines no defaults" do
      let(:target) { { a: 1 } }

      it "expect to leave the target untouched" do
        assert_equal({ a: 1 }, described_class.call(target))
      end

      it "expect to return the same target object" do
        assert_same target, described_class.call(target)
      end
    end

    context "when the injector defines defaults" do
      subject(:injector) do
        these = defaults

        Class.new(described_class) do
          define_singleton_method(:defaults) { these }
        end
      end

      let(:defaults) { { a: 1, b: 2 } }

      it "expect to inject the missing keys" do
        assert_equal({ a: 1, b: 2 }, injector.call({}))
      end

      it "expect not to overwrite keys already present" do
        assert_equal({ a: 10, b: 2 }, injector.call({ a: 10 }))
      end

      it "expect not to overwrite a key present with a nil value" do
        result = injector.call({ a: nil })

        assert_nil result[:a]
        assert_equal 2, result[:b]
      end

      it "expect not to overwrite a key present with a false value" do
        assert_equal({ a: false, b: 2 }, injector.call({ a: false }))
      end

      it "expect to mutate and return the same target object" do
        target = {}

        assert_same target, injector.call(target)
      end
    end
  end

  describe "layering via prepend + super" do
    subject(:injector) do
      these = base_defaults

      Class.new(described_class) do
        define_singleton_method(:defaults) { these }
      end
    end

    let(:base_defaults) { { a: 1, b: 2 }.freeze }

    let(:extension) do
      Module.new do
        def defaults
          super.merge(c: 3)
        end
      end
    end

    it "expect a layer to contribute additional defaults on top of the base" do
      injector.singleton_class.prepend(extension)

      assert_equal({ a: 1, b: 2, c: 3 }, injector.call({}))
    end

    it "expect an outer layer using super.merge to win a key shared with the base" do
      overriding = Module.new do
        def defaults
          super.merge(a: 99)
        end
      end

      injector.singleton_class.prepend(overriding)

      assert_equal 99, injector.call({})[:a]
    end

    it "expect the user's target value to survive regardless of layering" do
      injector.singleton_class.prepend(extension)

      assert_equal 10, injector.call({ a: 10 })[:a]
    end

    it "expect not to mutate the frozen base defaults when layering" do
      injector.singleton_class.prepend(extension)
      injector.call({})

      assert_equal({ a: 1, b: 2 }, base_defaults)
      refute base_defaults.key?(:c)
    end
  end
end
