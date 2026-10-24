# frozen_string_literal: true

describe_current do
  context "when operating on an instance basis" do
    subject(:tagged) { tagged_class.new }

    let(:other_tagged) { tagged_class.new }
    let(:tagged_class) do
      Class.new do
        include Karafka::Core::Taggable
      end
    end

    it { assert_empty tagged.tags.to_a }
    it { refute_equal other_tagged.tags, tagged.tags }

    it "expect not to add a Snapshot constant to the including class lookup" do
      refute tagged_class.const_defined?(:Snapshot)
    end
  end

  context "when several threads call tags first on the same objects" do
    let(:threads_count) { 4 }
    let(:objects) { Array.new(5_000) { tagged_class.new } }
    let(:seen) { Array.new(threads_count) { [] } }
    let(:tagged_class) do
      Class.new do
        include Karafka::Core::Taggable
      end
    end

    before do
      start = Queue.new
      fresh = objects
      handed_out = seen

      threads = Array.new(threads_count) do |thread_id|
        Thread.new do
          start.pop

          fresh.each do |object|
            tags = object.tags
            handed_out[thread_id] << tags
            tags.add(:"thread_#{thread_id}", thread_id)
          end
        end
      end

      threads_count.times { start << true }
      threads.each(&:join)
    end

    it "expect each object to hand out one tags instance" do
      split = objects.each_index.count do |index|
        seen.map { |thread_tags| thread_tags[index] }.uniq(&:object_id).size > 1
      end

      assert_equal 0, split
    end

    it "expect no tag to be lost" do
      assert(objects.all? { |object| object.tags.to_a.size == threads_count })
    end
  end

  context "when operating on a class basis" do
    subject(:tagged) { tagged_class }

    let(:other_tagged) { other_tagged_class }
    let(:tagged_class) do
      Class.new do
        extend Karafka::Core::Taggable
      end
    end
    let(:other_tagged_class) do
      Class.new do
        extend Karafka::Core::Taggable
      end
    end

    it { assert_empty tagged.tags.to_a }
    it { refute_equal other_tagged.tags, tagged.tags }
  end
end
