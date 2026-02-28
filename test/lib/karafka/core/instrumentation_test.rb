# frozen_string_literal: true

class KarafkaCoreInstrumentationTest < Minitest::Test
  def test_statistics_callbacks_is_callbacks_manager
    assert_kind_of(
      Karafka::Core::Instrumentation::CallbacksManager,
      Karafka::Core::Instrumentation.statistics_callbacks
    )
  end

  def test_error_callbacks_is_callbacks_manager
    assert_kind_of(
      Karafka::Core::Instrumentation::CallbacksManager,
      Karafka::Core::Instrumentation.error_callbacks
    )
  end

  def test_oauthbearer_token_refresh_callbacks_is_callbacks_manager
    assert_kind_of(
      Karafka::Core::Instrumentation::CallbacksManager,
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
    )
  end

  def test_statistics_callbacks_differs_from_error_callbacks
    refute_equal(
      Karafka::Core::Instrumentation.statistics_callbacks,
      Karafka::Core::Instrumentation.error_callbacks
    )
  end

  def test_error_callbacks_differs_from_oauthbearer_token_refresh_callbacks
    refute_equal(
      Karafka::Core::Instrumentation.error_callbacks,
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
    )
  end

  def test_statistics_callbacks_differs_from_oauthbearer_token_refresh_callbacks
    refute_equal(
      Karafka::Core::Instrumentation.statistics_callbacks,
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
    )
  end
end
