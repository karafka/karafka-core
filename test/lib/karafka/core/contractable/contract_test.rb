# frozen_string_literal: true

describe_current do
  subject(:validator_class) do
    Class.new(described_class) do
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

  describe "#validate!" do
    subject(:validation) { validator_class.new.validate!(data, ArgumentError) }

    context "when data is valid" do
      let(:data) { { id: "1" } }

      it { validation }
    end

    context "when data is not valid" do
      let(:data) { { id: 1 } }

      it { assert_raises(ArgumentError) { validation } }
    end

    context "when optional data is not valid" do
      let(:data) { { id: 1, test: Time.now } }

      it { assert_raises(ArgumentError) { validation } }
    end

    context "when optional name is not valid" do
      let(:data) { { id: 1, name: Time.now } }

      it { assert_raises(ArgumentError) { validation } }
    end

    context "when optional name is valid" do
      let(:data) { { id: "1", name: "name" } }

      it { validation }
    end

    context "when optional data is valid" do
      let(:data) { { id: 1, test: nil } }

      it { assert_raises(ArgumentError) { validation } }
    end

    context "when validating with extra scope details" do
      subject(:validation) do
        validator_class.new.validate!(data, ArgumentError, scope: [rand.to_s, rand.to_s])
      end

      context "when data is valid" do
        let(:data) { { id: "1" } }

        it { validation }
      end

      context "when data is not valid" do
        let(:data) { { id: 1 } }

        it { assert_raises(ArgumentError) { validation } }
      end

      context "when optional data is not valid" do
        let(:data) { { id: 1, test: Time.now } }

        it { assert_raises(ArgumentError) { validation } }
      end

      context "when optional name is not valid" do
        let(:data) { { id: 1, name: Time.now } }

        it { assert_raises(ArgumentError) { validation } }
      end

      context "when optional name is valid" do
        let(:data) { { id: "1", name: "name" } }

        it { validation }
      end

      context "when optional data is valid" do
        let(:data) { { id: 1, test: nil } }

        it { assert_raises(ArgumentError) { validation } }
      end
    end

    context "when error key is not available on error" do
      subject(:validator_class) do
        Class.new(described_class) do
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
            ).fetch("en").fetch("validations").fetch("config")
          end

          required(:na_id) { |id| id.is_a?(String) }
        end
      end

      let(:data) { { na_id: 1 } }

      it { assert_raises(KeyError) { validation } }
    end
  end

  describe "#call" do
    context "when interested in the errors and not raising" do
      subject(:validation) do
        validator_class.new.call(data, scope: scope)
      end

      let(:scope) { [rand.to_s, rand.to_s] }

      context "when data is valid" do
        let(:data) { { id: "1" } }

        it { assert_equal({}, validation.errors) }
      end

      context "when data is not valid" do
        let(:data) { { id: 1 } }

        it "expect to have the path key nested with the scope" do
          assert_includes validation.errors.keys, :"#{scope.join(".")}.id"
        end
      end
    end
  end

  context "when there are nested values in a contract" do
    let(:validator_class) do
      Class.new(described_class) do
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

    describe "#validate!" do
      subject(:validation) { validator_class.new.validate!(data, ArgumentError) }

      context "when data is valid without optional" do
        let(:data) { { nested: { id: "1" } } }

        it { validation }
      end

      context "when data is valid with optional" do
        let(:data) { { nested: { id: "1", id2: "2" } } }

        it { validation }
      end

      context "when data is not valid with invalid optional" do
        let(:data) { { nested: { id: "1", id2: 2 } } }

        it { assert_raises(ArgumentError) { validation } }
      end

      context "when data is not valid" do
        let(:data) { { id: 1 } }

        it { assert_raises(ArgumentError) { validation } }
      end
    end
  end

  context "when a deeply nested path encounters a non-hash intermediate value" do
    let(:validator_class) do
      Class.new(described_class) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("test")
        end

        nested(:level1) do
          nested(:level2) do
            required(:id) { |id| id.is_a?(String) }
          end
        end
      end
    end

    subject(:result) { validator_class.new.call(data) }

    context "when the full path is present" do
      let(:data) { { level1: { level2: { id: "1" } } } }

      it { assert_predicate result, :success? }
    end

    context "when an intermediate level is not a hash" do
      let(:data) { { level1: "not-a-hash" } }

      it "reports the path as missing instead of raising" do
        refute_predicate result, :success?
        assert result.errors.key?(:"level1.level2.id")
      end
    end
  end

  context "when the validated root is not a hash" do
    # Regression: the 1-key and 2-key dig fast paths called #fetch straight on the root and
    # raised NoMethodError for a non-Hash value, while the 3+-key path already reported the key
    # as missing. All path lengths now report a miss consistently.
    let(:validator_class) do
      Class.new(described_class) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("config")
        end

        required(:id) { |id| id.is_a?(String) }
        required(:a, :b) { |v| v.is_a?(String) }
      end
    end

    subject(:result) { validator_class.new.call("not-a-hash") }

    it "reports the required paths as missing instead of raising" do
      refute_predicate result, :success?
      assert result.errors.key?(:id)
      assert result.errors.key?(:"a.b")
    end
  end

  context "when contract has its own error reported" do
    let(:validator_class) do
      Class.new(described_class) do
        virtual do
          [[%i[id], "String error"]]
        end
      end
    end

    subject(:validation) { validator_class.new.validate!(data, ArgumentError) }

    context "when data is valid without optional" do
      let(:data) { { nested: { id: "1" } } }

      it { assert_raises(ArgumentError) { validation } }
    end
  end

  context "when a nested block raises during definition" do
    # Regression: nested pushed its path, ran the block, then popped -- with no ensure. If the
    # block raised and the caller rescued it, the path was left on @nested and prefixed onto
    # every rule defined afterwards.
    let(:validator_class) do
      Class.new(described_class) do
        begin
          nested(:a) { raise "boom" }
        rescue
          nil
        end

        required(:id) { |id| id.is_a?(String) }
      end
    end

    it "does not leak the nested path onto later rules" do
      assert_equal %i[id], validator_class.rules.last.path
    end
  end

  context "when a virtual rule returns a non-array value" do
    # Regression: a virtual rule returning false reached `false.each` and raised NoMethodError
    # (nil was already tolerated). Any non-Array result (true/false/nil) means "no errors".
    [false, nil, true].each do |returned|
      context "when it returns #{returned.inspect}" do
        let(:validator_class) do
          value = returned

          Class.new(described_class) do
            virtual { |_data, _errors, _contract| value }
          end
        end

        it { assert_predicate validator_class.new.call({}), :success? }
      end
    end
  end

  context "when contract has multiple nestings" do
    subject(:validator_class) do
      Class.new(described_class) do
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

    describe "#validate!" do
      subject(:validation) { validator_class.new.validate!(data, ArgumentError) }

      context "when data is valid" do
        let(:data) { { a: { b: { c: { id: "1" } } } } }

        it { validation }
      end

      context "when data is not valid" do
        let(:data) { { id: 1 } }

        it { assert_raises(ArgumentError) { validation } }
      end
    end
  end

  describe "virtual rule result array ownership" do
    # These document the `virtual` contract (see `Contract::DSL#virtual`): a rule returns a
    # freshly built Array of `[path, message]` pairs each call, and `#call` takes ownership of it
    # -- it prefixes the current scope onto each pair in place and collects them. They
    # characterize that intended behavior, they are not asserting a bug.

    context "when a virtual rule returns a fresh array each call (the supported pattern)" do
      subject(:validator_class) do
        Class.new(described_class) do
          virtual { |_data, _errors, _contract| [[%i[id], "boom"]] }
        end
      end

      let(:contract) { validator_class.new }

      it "scopes each error once and is stable across calls" do
        first = contract.call({}, scope: %i[outer]).errors
        second = contract.call({}, scope: %i[outer]).errors

        assert_equal({ "outer.id": "boom" }, first)
        assert_equal first, second
      end
    end

    context "when a virtual rule reuses the same array object (unsupported)" do
      # Documents the ownership contract: the returned pairs are scoped in place, so reusing the
      # same array across calls accumulates the scope prefix. Rules must return a fresh array.
      let(:reused) { [[%i[id], "boom"]] }

      subject(:validator_class) do
        memo = reused

        Class.new(described_class) do
          virtual { |_data, _errors, _contract| memo }
        end
      end

      let(:contract) { validator_class.new }

      it "scopes the reused array in place, accumulating the prefix across calls (by design)" do
        contract.call({}, scope: %i[outer])

        assert_equal [[%i[outer id], "boom"]], reused

        contract.call({}, scope: %i[outer])

        assert_equal [[%i[outer outer id], "boom"]], reused
      end
    end
  end
end
