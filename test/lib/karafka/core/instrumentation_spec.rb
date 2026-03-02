# frozen_string_literal: true

require "test_helper"

describe_current do
  subject(:instrumentation) { described_class }

  describe "#statistics_callbacks" do
    it { assert_kind_of described_class::CallbacksManager, instrumentation.statistics_callbacks }
  end

  describe "#error_callbacks" do
    it { assert_kind_of described_class::CallbacksManager, instrumentation.error_callbacks }
  end

  describe "#oauthbearer_token_refresh_callbacks" do
    it do
      assert_kind_of described_class::CallbacksManager,
        instrumentation.oauthbearer_token_refresh_callbacks
    end
  end

  it "expect statistics_callbacks to differ from error_callbacks" do
    refute_equal instrumentation.error_callbacks,
      instrumentation.statistics_callbacks
  end

  it "expect error_callbacks to differ from oauthbearer_token_refresh_callbacks" do
    refute_equal instrumentation.oauthbearer_token_refresh_callbacks,
      instrumentation.error_callbacks
  end

  it "expect statistics_callbacks to differ from oauthbearer_token_refresh_callbacks" do
    refute_equal instrumentation.oauthbearer_token_refresh_callbacks,
      instrumentation.statistics_callbacks
  end
end
