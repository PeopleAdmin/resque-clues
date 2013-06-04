require 'spec_helper'

CLUES = Resque::Plugins::Clues
describe Resque::Plugins::Clues do
  describe "#event_hash" do
    it "should generate different hashes for different times" do
      hash1 = CLUES.event_hash
      sleep(1)
      hash2 = CLUES.event_hash
      (hash1 == hash2).should == false
    end

    it "should generate different hashes for different processes" do
      hash = CLUES.event_hash
      fork {(hash == CLUES.event_hash).should == false}
      Process.wait
    end
  end

  describe "#symbolize" do
    it "should convert a hash with string keys to symbols 1 level deep" do
      CLUES.symbolize({"a" => 1}).should == {a: 1}
    end

    it "should convert a hash with string keys to symbols 2 levels deep" do
      CLUES.symbolize({"a" => {"b" => 2}}).should == {a: {b: 2}}
    end

    it "should convert a hash with string keys to symbols 3 levels deep" do
      CLUES.symbolize({"a" => {"b" => {"c" => 3}}}).should == {a: {b: {c: 3}}}
    end
  end

  describe "#time_delta_since" do
    it "should detect ~1 second run time" do
      start = Time.now.utc
      sleep(1)
      CLUES.time_delta_since(start).between?(0.99, 1.01).should == true
    end

    it "should not allow negative numbers (time sync)" do
      start = Time.now.utc + 1
      CLUES.time_delta_since(start).should == 0.0
    end
  end
end
