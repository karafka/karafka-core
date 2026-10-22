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

  context "when many threads add tags at once" do
    before do
      shared = tags

      Array.new(4) do |writer|
        Thread.new do
          1_000.times { |i| shared.add(:"tag_#{writer}_#{i}", "#{writer}-#{i}") }
        end
      end.each(&:join)
    end

    it "expect no tag to be lost" do
      assert_equal 4_000, tags.to_a.size
    end
  end

  context "when one thread changes tags while others read them" do
    let(:errors) { Queue.new }

    before do
      shared = tags
      failures = errors

      writer = Thread.new do
        20_000.times do |i|
          shared.add(:job_class, "Job#{i % 7}")
          shared.add(:attempt, "attempt: #{i}")
          shared.delete(:attempt) if i.odd?
        end

        shared.add(:final, "final")
      end

      readers = Array.new(3) do
        Thread.new do
          while writer.alive?
            begin
              shared.to_json
            rescue => e
              failures << e
            end
          end
        end
      end

      writer.join
      readers.each(&:join)
    end

    it "expect readers not to fail" do
      assert_empty Array.new(errors.size) { errors.pop }
    end

    it "expect readers to see the last change" do
      assert_equal %w[Job0 final], tags.to_a
    end
  end
end
