# frozen_string_literal: true

describe_current do
  before do
    @tags = Karafka::Core::Taggable::Tags.new
  end

  it "expect to be empty initially" do
    assert_empty @tags.to_a
  end

  describe "#add" do
    describe "when few under same name" do
      it "expect to keep last value" do
        3.times { |value| @tags.add(:name, value) }

        assert_equal %w[2], @tags.to_a
      end
    end

    describe "when with different names" do
      it "expect to keep all values" do
        @tags.add(:name1, 1)
        @tags.add(:name2, 2)
        @tags.add(:name3, 3)

        assert_equal %w[1 2 3], @tags.to_a
      end
    end

    describe "when with different names but same value" do
      it "expect to deduplicate" do
        @tags.add(:name1, 1)
        @tags.add(:name2, 1)
        @tags.add(:name3, 1)

        assert_equal %w[1], @tags.to_a
      end
    end
  end

  describe "#clear" do
    it "expect to remove all tags" do
      @tags.add(:name, 1)
      @tags.clear

      assert_empty @tags.to_a
    end
  end

  describe "#delete" do
    it "expect to remove the named tag" do
      @tags.add(:name1, 1)
      @tags.delete(:name1)
      @tags.add(:name3, 2)

      assert_equal %w[2], @tags.to_a
    end
  end

  describe "#to_json" do
    it "expect to serialize to JSON" do
      @tags.add(:test, "abc")

      assert_equal %w[abc].to_json, @tags.to_json
    end
  end

  describe "#as_json" do
    it "expect to return array representation" do
      @tags.add(:test, "abc")

      assert_equal %w[abc], @tags.as_json
    end
  end
end
