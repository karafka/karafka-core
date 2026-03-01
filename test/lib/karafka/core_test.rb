# frozen_string_literal: true

describe_current do
  describe "#gem_root" do
    it "expect to return current directory" do
      assert_equal Dir.pwd, Karafka::Core.gem_root.to_path
    end
  end
end
