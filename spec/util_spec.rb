require 'spec_helper'

describe Resque::Plugins::Clues do
  describe "#event_hash" do
    it "should generate different hashes for different times" do
      hash1 = Resque::Plugins::Clues.event_hash
      sleep(1)
      hash2 = Resque::Plugins::Clues.event_hash
      (hash1 == hash2).should == false
    end

    it "should generate different hashes for different processes" do
      hash = Resque::Plugins::Clues.event_hash
      fork {(hash == Resque::Plugins::Clues.event_hash).should == false}
      Process.wait
    end
  end

  describe "#time_delta_since" do
    it "should detect ~1 second run time" do
      start = Time.now.utc
      sleep(1)
      Resque::Plugins::Clues.time_delta_since(start).between?(0.99, 1.01).should == true
    end

    it "should not allow negative numbers (time sync)" do
      start = Time.now.utc + 1
      Resque::Plugins::Clues.time_delta_since(start).should == 0.0
    end
  end
end
