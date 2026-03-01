# frozen_string_literal: true

describe_current do
  def build_contract
    Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      required(:id) { |id| id.is_a?(String) }
      optional(:test) { |test| test == 5 }
    end
  end

  describe "when there are no errors" do
    before do
      @result = build_contract.new.call({ id: "123", test: 5 })
    end

    it "expect to return success" do
      assert_same true, @result.success?
    end

    it "expect to have no errors" do
      assert_empty @result.errors
    end
  end

  describe "when there are errors and all keys can be mapped to messages" do
    before do
      @result = build_contract.new.call({ id: 123, test: 4 })
    end

    it "expect not to return success" do
      assert_same false, @result.success?
    end

    it "expect to map errors to messages" do
      assert_equal(
        { id: "needs to be a String", test: "needs to be 5" },
        @result.errors
      )
    end
  end

  describe "when there are errors with nested keys" do
    it "expect to map nested errors to messages with dot notation" do
      contract_class = Class.new(Karafka::Core::Contractable::Contract) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("test")
        end

        nested(:details) do
          required(:id) { |id| id.is_a?(String) }
        end
      end

      result = contract_class.new.call({ details: { id: 123 } })

      assert_same false, result.success?
      assert_equal(
        { "details.id": "needs to be a String" },
        result.errors
      )
    end
  end

  describe "when there are errors and key cannot be mapped to a message" do
    it "expect to fall back to a generic error message" do
      contract_class = Class.new(Karafka::Core::Contractable::Contract) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("test")
        end

        required(:id) { |id| id.is_a?(String) }
      end

      result = contract_class.new.call({ id: 123 })

      assert_same false, result.success?
      assert_equal(
        { id: "needs to be a String" },
        result.errors
      )
    end
  end
end
