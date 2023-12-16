# frozen_string_literal: true

RSpec.describe_current do
  subject(:core) { described_class }

  describe '#gem_root' do
    context 'when we want to get gem root path' do
      let(:path) { Dir.pwd }

      it { expect(core.gem_root.to_path).to eq path }
    end
  end

  describe 'modules files existence' do
    let(:lib_location) { File.join(Karafka::Core.gem_root, 'lib', 'karafka', 'core', '**/**') }
    let(:candidates) { Dir[lib_location].to_a }

    it do
      failed = candidates.select do |path|
        File.directory?(path) && !File.exist?("#{path}.rb")
      end

      expect(failed).to eq([])
    end
  end
end
