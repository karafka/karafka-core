# frozen_string_literal: true

class KarafkaCoreTaggableTagsTest < Minitest::Test
  def setup
    @tags = Karafka::Core::Taggable::Tags.new
  end

  def test_initially_empty
    assert_empty @tags.to_a
  end

  def test_add_same_name_keeps_last_value
    3.times { |value| @tags.add(:name, value) }

    assert_equal %w[2], @tags.to_a
  end

  def test_add_different_names
    @tags.add(:name1, 1)
    @tags.add(:name2, 2)
    @tags.add(:name3, 3)

    assert_equal %w[1 2 3], @tags.to_a
  end

  def test_add_different_names_same_value
    @tags.add(:name1, 1)
    @tags.add(:name2, 1)
    @tags.add(:name3, 1)

    assert_equal %w[1], @tags.to_a
  end

  def test_clear
    @tags.add(:name, 1)
    @tags.clear

    assert_empty @tags.to_a
  end

  def test_delete
    @tags.add(:name1, 1)
    @tags.delete(:name1)
    @tags.add(:name3, 2)

    assert_equal %w[2], @tags.to_a
  end

  def test_to_json
    @tags.add(:test, "abc")

    assert_equal %w[abc].to_json, @tags.to_json
  end

  def test_as_json
    @tags.add(:test, "abc")

    assert_equal %w[abc], @tags.as_json
  end
end
