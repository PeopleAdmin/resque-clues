require 'spec_helper'

describe Resque::Plugins::Clues::QueueDecorator do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::QueueDecorator) 
  end

  before do
    Resque.send(:extend, Resque::Plugins::Clues::QueueDecorator)
  end 

  it "should expose original push method as _base_push" do
    Resque.respond_to?(:_base_push).should == true
  end

  it "should expose original pop method as _base_pop" do
    Resque.respond_to?(:_base_pop).should == true 
  end

  describe "#push" do
    it "should invoke _base_push with a queue and item args and return the result" do 
      Resque.stub(:_base_push) do |queue, item|
        queue.should == :test_queue
        item.nil?.should == false
        "received"
      end
      Resque.push(:test_queue, {}).should == "received"
    end

    context "adds metadata to item stored in redis" do
      it "should contain an event_hash identifying the job entering the queue" do
        Resque.stub(:_base_push) do |queue, item|
          item[:metadata][:event_hash].nil?.should == false
        end
        Resque.push(:test_queue, {})
      end
    end
  end

  describe "#pop" do
    it "should invoke _base_pop with a queue arg and return the result" do
      Resque.stub(:_base_pop) do |queue|
        queue.should == :test_queue
        "received"
      end
      Resque.pop(:test_queue).should == "received"
    end
  end
end
