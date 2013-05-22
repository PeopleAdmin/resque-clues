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
    def validate
      Resque.stub(:_base_push) do |queue, item|
        yield(queue, item)
      end
    end

    it "should invoke _base_push with a queue and item args and return the result" do 
      validate do |queue, item|
        queue.should == :test_queue
        item.nil?.should == false
        "received"
      end
      Resque.push(:test_queue, {}).should == "received"
    end

    context "adds metadata to item stored in redis that" do
      it "should contain an event_hash identifying the job entering the queue" do
        validate {|queue, item| item[:metadata][:event_hash].nil?.should == false}
        Resque.push(:test_queue, {})
      end

      it "should contain the host's hostname" do
        validate {|queue, item| item[:metadata][:hostname].should == `hostname`.strip}
        Resque.push(:test_queue, {})
      end

      it "should contain the process id" do
        validate {|queue, item| item[:metadata][:process].should == $$}
        Resque.push(:test_queue, {})
      end

      it "should allow an item_preprocessor to inject arbitrary data" do
        Resque.item_preprocessor = proc {|queue, item| item[:metadata][:employer_id] = 1}
        validate {|queue, item| item[:metadata][:employer_id].should == 1}
        Resque.push(:test_queue, {})
      end
    end
  end

  describe "#pop" do
    it "should invoke _base_pop with a queue arg and return the result" do
      Resque.stub(:_base_pop) do |queue|
        queue.should == :test_queue
        {metadata: {}}
      end
      Resque.pop(:test_queue).nil?.should == false
    end

    context "metadata in the item retrieved from redis" do
      before do 
        Resque.stub(:_base_pop){{metadata: {}}}
      end

      it "should contain the hostname" do
        Resque.pop(:test_queue)[:metadata][:hostname].should == `hostname`.chop
      end

      it "should contain the process id" do
        Resque.pop(:test_queue)[:metadata][:process].should == $$
      end

      it "should contain an enqueued_time" do
        Resque.pop(:test_queue)[:metadata][:time_in_queue].nil?.should == false
      end
    end
  end
end
