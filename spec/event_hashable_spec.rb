require 'spec_helper'

describe Resque::Plugins::Clues::EventHashable do
  before do
    self.extend(Resque::Plugins::Clues::EventHashable)
  end

  describe "#event_hash" do
    it "should generate different hashes for different times" do
      hash1 = event_hash
      sleep(1)
      hash2 = event_hash
      (hash1 == hash2).should == false
    end

    it "should generate different hashes for different processes" do
      hash = event_hash
      fork {(hash == event_hash).should == false}
      Process.wait
    end
  end
end
