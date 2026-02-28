# frozen_string_literal: true

class KarafkaCoreTaggableInstanceTest < Minitest::Test
  def setup
    @tagged_class = Class.new { include Karafka::Core::Taggable }
  end

  def test_tags_empty_initially
    assert_empty @tagged_class.new.tags.to_a
  end

  def test_tags_differ_between_instances
    refute_equal @tagged_class.new.tags, @tagged_class.new.tags
  end
end

class KarafkaCoreTaggableClassTest < Minitest::Test
  def setup
    @tagged_class = Class.new { extend Karafka::Core::Taggable }
    @other_tagged_class = Class.new { extend Karafka::Core::Taggable }
  end

  def test_tags_empty_initially
    assert_empty @tagged_class.tags.to_a
  end

  def test_tags_differ_between_classes
    refute_equal @tagged_class.tags, @other_tagged_class.tags
  end
end
