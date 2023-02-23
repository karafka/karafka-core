# frozen_string_literal: true

RSpec.describe_current do
  subject(:tags) { described_class.new }

  it { expect(tags.to_a).to be_empty }

  describe '#add' do
    context 'when few under same name' do
      before { 3.times { |value| tags.add(:name, value) } }

      it { expect(tags.to_a).to eq(%w[2]) }
    end

    context 'when with different names' do
      before do
        tags.add(:name1, 1)
        tags.add(:name2, 2)
        tags.add(:name3, 3)
      end

      it { expect(tags.to_a).to eq(%w[1 2 3]) }
    end

    context 'when with different names but same value' do
      before do
        tags.add(:name1, 1)
        tags.add(:name2, 1)
        tags.add(:name3, 1)
      end

      it { expect(tags.to_a).to eq(%w[1]) }
    end
  end

  describe '#clear' do
    before do
      tags.add(:name, 1)
      tags.clear
    end

    it { expect(tags.to_a).to be_empty }
  end

  describe '#delete' do
    before do
      tags.add(:name1, 1)
      tags.delete(:name1)
      tags.add(:name3, 2)
    end

    it { expect(tags.to_a).to eq(%w[2]) }
  end

  describe '#to_json' do
    before { tags.add(:test, 'abc') }

    it { expect(tags.to_json).to eq(%w[abc].to_json) }
  end

  describe '#as_json' do
    before { tags.add(:test, 'abc') }

    it { expect(tags.as_json).to eq(%w[abc]) }
  end
end
