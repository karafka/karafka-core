# frozen_string_literal: true

require "test_helper"

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
end
