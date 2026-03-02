# frozen_string_literal: true

describe_current do
  subject(:tags) { described_class.new }

  it { assert_empty tags.to_a }

  describe "#add" do
    context "when few under same name" do
      before { 3.times { |value| tags.add(:name, value) } }

      it { assert_equal %w[2], tags.to_a }
    end

    context "when with different names" do
      before do
        tags.add(:name1, 1)
        tags.add(:name2, 2)
        tags.add(:name3, 3)
      end

      it { assert_equal %w[1 2 3], tags.to_a }
    end

    context "when with different names but same value" do
      before do
        tags.add(:name1, 1)
        tags.add(:name2, 1)
        tags.add(:name3, 1)
      end

      it { assert_equal %w[1], tags.to_a }
    end
  end

  describe "#clear" do
    before do
      tags.add(:name, 1)
      tags.clear
    end

    it { assert_empty tags.to_a }
  end

  describe "#delete" do
    before do
      tags.add(:name1, 1)
      tags.delete(:name1)
      tags.add(:name3, 2)
    end

    it { assert_equal %w[2], tags.to_a }
  end

  describe "#to_json" do
    before { tags.add(:test, "abc") }

    it { assert_equal %w[abc].to_json, tags.to_json }
  end

  describe "#as_json" do
    before { tags.add(:test, "abc") }

    it { assert_equal %w[abc], tags.as_json }
  end
end
