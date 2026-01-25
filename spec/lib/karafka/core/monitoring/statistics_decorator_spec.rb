# frozen_string_literal: true

RSpec.describe_current do
  subject(:decorator) { described_class.new }

  let(:emited_stats1) do
    {
      "string" => "value1",
      "float" => 10.4,
      "int" => 112,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 123
          }
        }
      }
    }
  end

  let(:emited_stats2) do
    {
      "string" => "value2",
      "float" => 10.8,
      "int" => 130,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 153
          }
        }
      }
    }
  end

  let(:emited_stats3) do
    {
      "string" => "value3",
      "float" => 11.8,
      "int" => 10,
      "nested" => {
        "brokers" => {
          "localhost:9092/2" => {
            "txbytes" => 2
          }
        }
      }
    }
  end

  let(:broker_scope) { %w[nested brokers localhost:9092/2] }

  context "when it is a first stats emit" do
    subject(:decorated) { decorator.call(emited_stats1) }

    it { expect(decorated["string"]).to eq("value1") }
    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated["float_d"]).to eq(0) }
    it { expect(decorated["int_d"]).to eq(0) }
    it { expect(decorated.dig(*broker_scope)["txbytes_d"]).to eq(0) }
    it { expect(decorated).to be_frozen }
  end

  context "when it is a second stats emit" do
    subject(:decorated) do
      decorator.call(emited_stats1)
      decorator.call(emited_stats2)
    end

    it { expect(decorated["string"]).to eq("value2") }
    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated["float_d"].round(10)).to eq(0.4) }
    it { expect(decorated["int_d"]).to eq(18) }
    it { expect(decorated.dig(*broker_scope)["txbytes_d"]).to eq(30) }
    it { expect(decorated).to be_frozen }
  end

  context "when it is a third stats emit" do
    subject(:decorated) do
      decorator.call(emited_stats1)
      decorator.call(emited_stats2)
      decorator.call(emited_stats3)
    end

    it { expect(decorated["string"]).to eq("value3") }
    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated.key?("string_fd")).to be(false) }
    it { expect(decorated["float_d"].round(10)).to eq(1.0) }
    it { expect(decorated["float_fd"]).to be_within(5).of(0) }
    it { expect(decorated["int_d"]).to eq(-120) }
    it { expect(decorated["int_fd"]).to be_within(5).of(0) }
    it { expect(decorated.dig(*broker_scope)["txbytes_d"]).to eq(-151) }
    it { expect(decorated.dig(*broker_scope)["txbytes_fd"]).to be_within(5).of(0) }
    it { expect(decorated).to be_frozen }
    it { expect(decorated.key?("float_d_d")).to be(false) }
  end

  context "when a broker is no longer present" do
    subject(:decorated) do
      decorator.call(emited_stats1)
      decorator.call(emited_stats2)
    end

    before { emited_stats2["nested"] = {} }

    it { expect(decorated["string"]).to eq("value2") }
    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated.key?("string_fd")).to be(false) }
    it { expect(decorated["float_d"].round(10)).to eq(0.4) }
    it { expect(decorated["float_fd"]).to be_within(5).of(0) }
    it { expect(decorated["int_d"]).to eq(18) }
    it { expect(decorated["int_fd"]).to be_within(5).of(0) }
    it { expect(decorated["nested"]).to eq({}) }
    it { expect(decorated).to be_frozen }
    it { expect(decorated.key?("float_d_d")).to be(false) }
  end

  context "when broker was introduced later on" do
    subject(:decorated) do
      decorator.call(emited_stats1)
      decorator.call(emited_stats2)
    end

    before { emited_stats1["nested"] = {} }

    it { expect(decorated["string"]).to eq("value2") }
    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated["float_d"].round(10)).to eq(0.4) }
    it { expect(decorated["float_fd"]).to be_within(5).of(0) }
    it { expect(decorated["int_d"]).to eq(18) }
    it { expect(decorated["int_fd"]).to be_within(5).of(0) }
    it { expect(decorated.dig(*broker_scope)["txbytes_d"]).to eq(0) }
    it { expect(decorated.dig(*broker_scope)["txbytes_fd"]).to be_within(5).of(0) }
    it { expect(decorated).to be_frozen }
    it { expect(decorated.key?("float_d_d")).to be(false) }
  end

  context "when value remains unchanged over time" do
    subject(:decorated) do
      # First one will set initial state
      decorator.call(deep_copy.call)
      # Second one will build first deltas with freeze duration of zero
      decorator.call(deep_copy.call)
      sleep(0.01)
      # Third one will allow for proper freeze duration computation
      decorator.call(deep_copy.call)
    end

    let(:deep_copy) { -> { Marshal.load(Marshal.dump(emited_stats1)) } }

    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated.key?("string_fd")).to be(false) }
    it { expect(decorated["float_d"]).to eq(0) }
    it { expect(decorated["float_fd"]).to be_within(5).of(10) }
    it { expect(decorated["int_d"]).to eq(0) }
    it { expect(decorated["int_fd"]).to be_within(5).of(10) }
    it { expect(decorated).to be_frozen }
    it { expect(decorated.key?("float_d_d")).to be(false) }
  end

  context "when value remains unchanged over multiple occurrences and time" do
    subject(:decorated) do
      # First one will set initial state
      decorator.call(deep_copy.call)
      # Second one will build first deltas with freeze duration of zero
      decorator.call(deep_copy.call)
      sleep(0.01)
      # Third one will allow for proper freeze duration computation
      decorator.call(deep_copy.call)
      sleep(0.01)
      decorator.call(deep_copy.call)
    end

    let(:deep_copy) { -> { Marshal.load(Marshal.dump(emited_stats1)) } }

    it { expect(decorated.key?("string_d")).to be(false) }
    it { expect(decorated.key?("string_fd")).to be(false) }
    it { expect(decorated["float_d"]).to eq(0) }
    it { expect(decorated["float_fd"]).to be_within(5).of(20) }
    it { expect(decorated["int_d"]).to eq(0) }
    # On slow CIs this value tends to grow and crash
    it { expect(decorated["int_fd"]).to be_within(15).of(20) }
    it { expect(decorated).to be_frozen }
    it { expect(decorated.key?("float_d_d")).to be(false) }
  end
end
