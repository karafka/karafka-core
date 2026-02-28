# frozen_string_literal: true

class KarafkaCoreVersionTest < Minitest::Test
  def test_version_constant_exists
    Karafka::Core::VERSION
  end
end
