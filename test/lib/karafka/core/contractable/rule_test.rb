# frozen_string_literal: true

describe_current do
  it "expect to inherit from Struct" do
    assert_operator Karafka::Core::Contractable::Rule, :<, Struct
  end
end
