# frozen_string_literal: true

describe_current do
  def build_validator
    Class.new(Karafka::Core::Contractable::Contract) do
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
    describe "when data is valid" do
      it "expect not to raise" do
        build_validator.new.validate!({ id: "1" }, ArgumentError)
      end
    end

    describe "when data is not valid" do
      it "expect to raise" do
        assert_raises(ArgumentError) do
          build_validator.new.validate!({ id: 1 }, ArgumentError)
        end
      end
    end

    describe "when optional data is not valid" do
      it "expect to raise" do
        assert_raises(ArgumentError) do
          build_validator.new.validate!({ id: 1, test: Time.now }, ArgumentError)
        end
      end
    end

    describe "when optional name is not valid" do
      it "expect to raise" do
        assert_raises(ArgumentError) do
          build_validator.new.validate!({ id: 1, name: Time.now }, ArgumentError)
        end
      end
    end

    describe "when optional name is valid" do
      it "expect not to raise" do
        build_validator.new.validate!({ id: "1", name: "name" }, ArgumentError)
      end
    end

    describe "when optional data is nil" do
      it "expect to raise" do
        assert_raises(ArgumentError) do
          build_validator.new.validate!({ id: 1, test: nil }, ArgumentError)
        end
      end
    end

    describe "when validating with extra scope details" do
      describe "when data is valid" do
        it "expect not to raise" do
          build_validator.new.validate!({ id: "1" }, ArgumentError, scope: [rand.to_s, rand.to_s])
        end
      end

      describe "when data is not valid" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            build_validator.new.validate!({ id: 1 }, ArgumentError, scope: [rand.to_s, rand.to_s])
          end
        end
      end

      describe "when optional data is not valid" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            build_validator.new.validate!(
              { id: 1, test: Time.now }, ArgumentError, scope: [rand.to_s, rand.to_s]
            )
          end
        end
      end

      describe "when optional name is not valid" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            build_validator.new.validate!(
              { id: 1, name: Time.now }, ArgumentError, scope: [rand.to_s, rand.to_s]
            )
          end
        end
      end

      describe "when optional name is valid" do
        it "expect not to raise" do
          build_validator.new.validate!(
            { id: "1", name: "name" }, ArgumentError, scope: [rand.to_s, rand.to_s]
          )
        end
      end

      describe "when optional data is nil" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            build_validator.new.validate!(
              { id: 1, test: nil }, ArgumentError, scope: [rand.to_s, rand.to_s]
            )
          end
        end
      end
    end

    describe "when error key is not available on error" do
      it "expect to raise KeyError" do
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
  end

  describe "#call" do
    describe "when interested in the errors and not raising" do
      describe "when data is valid" do
        it "expect to have no errors" do
          scope = [rand.to_s, rand.to_s]
          result = build_validator.new.call({ id: "1" }, scope: scope)

          assert_equal({}, result.errors)
        end
      end

      describe "when data is not valid" do
        it "expect to have the path key nested with the scope" do
          scope = [rand.to_s, rand.to_s]
          result = build_validator.new.call({ id: 1 }, scope: scope)

          assert_includes result.errors.keys, :"#{scope.join(".")}.id"
        end
      end
    end
  end

  describe "when there are nested values in a contract" do
    def nested_validator
      Class.new(Karafka::Core::Contractable::Contract) do
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
      describe "when data is valid without optional" do
        it "expect not to raise" do
          nested_validator.new.validate!({ nested: { id: "1" } }, ArgumentError)
        end
      end

      describe "when data is valid with optional" do
        it "expect not to raise" do
          nested_validator.new.validate!({ nested: { id: "1", id2: "2" } }, ArgumentError)
        end
      end

      describe "when data is not valid with invalid optional" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            nested_validator.new.validate!({ nested: { id: "1", id2: 2 } }, ArgumentError)
          end
        end
      end

      describe "when data is not valid" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            nested_validator.new.validate!({ id: 1 }, ArgumentError)
          end
        end
      end
    end
  end

  describe "when contract has its own error reported" do
    it "expect to raise" do
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

  describe "when contract has multiple nestings" do
    def deeply_nested_validator
      Class.new(Karafka::Core::Contractable::Contract) do
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
      describe "when data is valid" do
        it "expect not to raise" do
          deeply_nested_validator.new.validate!(
            { a: { b: { c: { id: "1" } } } }, ArgumentError
          )
        end
      end

      describe "when data is not valid" do
        it "expect to raise" do
          assert_raises(ArgumentError) do
            deeply_nested_validator.new.validate!({ id: 1 }, ArgumentError)
          end
        end
      end
    end
  end
end
