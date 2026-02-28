# frozen_string_literal: true

class KarafkaCoreContractableRuleTest < Minitest::Test
  def test_rule_inherits_from_struct
    assert_operator Karafka::Core::Contractable::Rule, :<, Struct
  end
end
