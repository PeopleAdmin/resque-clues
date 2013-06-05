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

  describe Resque::Plugins::Clues::LooseHash do
    before {@item = Resque::Plugins::Clues::LooseHash.new({})}

    context "with a value for a string key" do
      before {@item['a'] = true}

      it "should allow access to the value through the string key" do
        @item['a'].should == true
      end

      it "should allow access to the value through an equivalent symbol key" do
        @item[:a].should == true
      end
    end

    context "with a value for a symbol key" do
      before {@item[:a] = true}

      it "should allow access to the value through the symbol key" do
        @item[:a].should == true
      end

      it "should allow access to the value through an equivalent string key" do
        @item['a'].should == true
      end
    end
  end
end
