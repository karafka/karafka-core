# frozen_string_literal: true

describe_current do
  describe "#statistics_callbacks" do
    it "expect to be a CallbacksManager" do
      assert_kind_of(
        Karafka::Core::Instrumentation::CallbacksManager,
        Karafka::Core::Instrumentation.statistics_callbacks
      )
    end
  end

  describe "#error_callbacks" do
    it "expect to be a CallbacksManager" do
      assert_kind_of(
        Karafka::Core::Instrumentation::CallbacksManager,
        Karafka::Core::Instrumentation.error_callbacks
      )
    end
  end

  describe "#oauthbearer_token_refresh_callbacks" do
    it "expect to be a CallbacksManager" do
      assert_kind_of(
        Karafka::Core::Instrumentation::CallbacksManager,
        Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
      )
    end
  end

  it "expect statistics_callbacks to differ from error_callbacks" do
    refute_equal(
      Karafka::Core::Instrumentation.statistics_callbacks,
      Karafka::Core::Instrumentation.error_callbacks
    )
  end

  it "expect error_callbacks to differ from oauthbearer_token_refresh_callbacks" do
    refute_equal(
      Karafka::Core::Instrumentation.error_callbacks,
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
    )
  end

  it "expect statistics_callbacks to differ from oauthbearer_token_refresh_callbacks" do
    refute_equal(
      Karafka::Core::Instrumentation.statistics_callbacks,
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
    )
  end
end
