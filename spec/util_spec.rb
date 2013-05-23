require 'spec_helper'

describe Resque::Plugins::Clues::Util do
  before {extend(Resque::Plugins::Clues::Util)}

  describe "#symbolize" do
    it "should convert a hash with string keys to symbols 1 level deep" do
      symbolize({"a" => 1}).should == {a: 1}
    end

    it "should convert a hash with string keys to symbols 2 levels deep" do
      symbolize({"a" => {"b" => 2}}).should == {a: {b: 2}}
    end

    it "should convert a hash with string keys to symbols 3 levels deep" do
      symbolize({"a" => {"b" => {"c" => 3}}}).should == {a: {b: {c: 3}}}
    end
  end
end
