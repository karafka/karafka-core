# frozen_string_literal: true

describe_current do
  subject(:core) { described_class }

  describe "#gem_root" do
    context "when we want to get gem root path" do
      let(:path) { Dir.pwd }

      it { assert_equal path, core.gem_root.to_path }
    end
  end
end
