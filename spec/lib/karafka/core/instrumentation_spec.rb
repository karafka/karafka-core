# frozen_string_literal: true

RSpec.describe_current do
  subject(:instrumentation) { described_class }

  describe '#statistics_callbacks' do
    it { expect(instrumentation.statistics_callbacks).to be_a(described_class::CallbacksManager) }
  end

  describe '#error_callbacks' do
    it { expect(instrumentation.error_callbacks).to be_a(described_class::CallbacksManager) }
  end

  describe '#oauthbearer_token_refresh_callbacks' do
    it do
      expect(instrumentation.oauthbearer_token_refresh_callbacks)
        .to be_a(described_class::CallbacksManager)
    end
  end

  it 'expect statistics_callbacks to differ from error_callbacks' do
    expect(instrumentation.statistics_callbacks)
      .not_to eq(instrumentation.error_callbacks)
  end

  it 'expect error_callbacks to differ from oauthbearer_token_refresh_callbacks' do
    expect(instrumentation.error_callbacks)
      .not_to eq(instrumentation.oauthbearer_token_refresh_callbacks)
  end

  it 'expect statistics_callbacks to differ from oauthbearer_token_refresh_callbacks' do
    expect(instrumentation.statistics_callbacks)
      .not_to eq(instrumentation.oauthbearer_token_refresh_callbacks)
  end
end
