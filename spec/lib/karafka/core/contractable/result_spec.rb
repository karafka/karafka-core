# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract_class) do
    Class.new(Karafka::Core::Contractable::Contract) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka::Core.gem_root, 'config', 'locales', 'errors.yml')
        ).fetch('en').fetch('validations').fetch('test')
      end

      required(:id) { |id| id.is_a?(String) }

      optional(:test) { |test| test == 5 }
    end
  end

  let(:contract) { contract_class.new }

  context 'when there are no errors' do
    let(:data) { { id: '123', test: 5 } }
    let(:result) { contract.call(data) }

    it 'returns success' do
      expect(result.success?).to be true
    end

    it 'has no errors' do
      expect(result.errors).to be_empty
    end
  end

  context 'when there are errors and all keys can be mapped to messages' do
    let(:data) { { id: 123, test: 4 } }
    let(:result) { contract.call(data) }

    it 'does not return success' do
      expect(result.success?).to be false
    end

    it 'maps errors to messages' do
      expect(result.errors).to eq(
        id: 'needs to be a String',
        test: 'needs to be 5'
      )
    end
  end

  context 'when there are errors with nested keys' do
    subject(:contract_class) do
      Class.new(Karafka::Core::Contractable::Contract) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, 'config', 'locales', 'errors.yml')
          ).fetch('en').fetch('validations').fetch('test')
        end

        nested(:details) do
          required(:id) { |id| id.is_a?(String) }
        end
      end
    end

    let(:data) { { details: { id: 123 } } }
    let(:result) { contract.call(data) }

    it 'does not return success' do
      expect(result.success?).to be false
    end

    it 'maps nested errors to messages with dot notation' do
      expect(result.errors).to eq(
        'details.id': 'needs to be a String'
      )
    end
  end

  context 'when there are errors and key cannot be mapped to a message' do
    subject(:contract_class) do
      Class.new(Karafka::Core::Contractable::Contract) do
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka::Core.gem_root, 'config', 'locales', 'errors.yml')
          ).fetch('en').fetch('validations').fetch('test')
        end

        required(:id) { |id| id.is_a?(String) }
      end
    end

    let(:data) { { id: 123 } }
    let(:result) { contract.call(data) }

    it 'does not return success' do
      expect(result.success?).to be false
    end

    it 'falls back to a generic error message' do
      expect(result.errors).to eq(
        id: 'needs to be a String'
      )
    end
  end
end
