# frozen_string_literal: true

RSpec.describe_current do
  context "when operating on an instance basis" do
    subject(:tagged) { tagged_class.new }

    let(:other_tagged) { tagged_class.new }
    let(:tagged_class) do
      Class.new do
        include Karafka::Core::Taggable
      end
    end

    it { expect(tagged.tags.to_a).to be_empty }
    it { expect(tagged.tags).not_to eq(other_tagged.tags) }
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

    it { expect(tagged.tags.to_a).to be_empty }
    it { expect(tagged.tags).not_to eq(other_tagged.tags) }
  end
end
