# frozen_string_literal: true

describe_current do
  describe "when operating on an instance basis" do
    before do
      @tagged_class = Class.new { include Karafka::Core::Taggable }
    end

    it "expect tags to be empty initially" do
      assert_empty @tagged_class.new.tags.to_a
    end

    it "expect tags to differ between instances" do
      refute_equal @tagged_class.new.tags, @tagged_class.new.tags
    end
  end

  describe "when operating on a class basis" do
    before do
      @tagged_class = Class.new { extend Karafka::Core::Taggable }
      @other_tagged_class = Class.new { extend Karafka::Core::Taggable }
    end

    it "expect tags to be empty initially" do
      assert_empty @tagged_class.tags.to_a
    end

    it "expect tags to differ between classes" do
      refute_equal @tagged_class.tags, @other_tagged_class.tags
    end
  end
end
