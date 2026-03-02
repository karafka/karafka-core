# frozen_string_literal: true

require "test_helper"

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
