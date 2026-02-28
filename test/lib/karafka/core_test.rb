# frozen_string_literal: true

class KarafkaCoreTest < Minitest::Test
  def test_gem_root_returns_current_directory
    assert_equal Dir.pwd, Karafka::Core.gem_root.to_path
  end
end
