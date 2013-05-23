require 'spec_helper'

describe Resque::Plugins::Clues::QueueDecorator do
  def base_item(overrides={})
    {"class" => "TestWorker", "args" => [1,2].to_s}.merge!(overrides)
  end

  def publishes(evt_type)
    Resque.event_publisher.stub(evt_type) do |time, queue, metadata, klass, args|
      time.nil?.should == false
      queue.should == :test_queue
      klass.should == 'TestWorker'
      args.should == [1,2].to_s
      yield(metadata)
    end
  end

  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::QueueDecorator)
  end

  before do
    Resque.send(:alias_method, :_base_push, :push)
    Resque.send(:alias_method, :_base_pop, :pop)
    Resque.send(:extend, Resque::Plugins::Clues::QueueDecorator)
  end

  it "should expose original push method as _base_push" do
    Resque.respond_to?(:_base_push).should == true
  end

  it "should expose original pop method as _base_pop" do
    Resque.respond_to?(:_base_pop).should == true
  end

  context "with no event_publisher configured" do
    describe "#push" do
      it "should delegate directly to original Resque push method" do
        Resque.should_receive(:_base_push).with(:test_queue, {})
        Resque.push(:test_queue, {})
      end
    end

    describe "#pop" do
      it "should delegate directly to original Resque pop method" do
        Resque.stub(:_base_pop) do |queue|
          queue.should == :test_queue
          {}
        end
        Resque.pop(:test_queue).should == {}
      end
    end
  end

  context "with event_publisher configured" do
    before {Resque.event_publisher = Resque::Plugins::Clues::EventPublisher::StandardOut.new}

    describe "#push" do
      it "should invoke _base_push with a queue and item args and return the result" do
        item_result = base_item
        Resque.stub(:_base_push) do |queue, item|
          queue.should == :test_queue
          item[:class].should == "TestWorker"
          item[:args].should == [1,2].to_s
          "received"
        end
        Resque.push(:test_queue, base_item).should == "received"
      end

      context "adds metadata to item stored in redis that" do
        it "should contain an event_hash identifying the job entering the queue" do
          publishes(:enqueued) {|metadata| metadata[:event_hash].nil?.should == false}
          Resque.push(:test_queue, base_item)
        end

        it "should contain the host's hostname" do
          publishes(:enqueued) {|metadata| metadata[:hostname].should == `hostname`.strip}
          Resque.push(:test_queue, base_item)
        end

        it "should contain the process id" do
          publishes(:enqueued) {|metadata| metadata[:process].should == $$}
          Resque.push(:test_queue, base_item)
        end

        it "should allow an item_preprocessor to inject arbitrary data" do
          Resque.item_preprocessor = proc {|queue, item| item[:metadata][:employer_id] = 1}
          publishes(:enqueued) {|metadata| metadata[:employer_id].should == 1}
          Resque.push(:test_queue, base_item)
        end
      end
    end

    describe "#pop" do
      it "should invoke _base_pop with a queue arg and return the result" do
        result = base_item 'metadata' => {}
        Resque.stub(:_base_pop) do |queue|
          queue.should == :test_queue
          result
        end
        Resque.pop(:test_queue).should == result
      end

      context "when retrieving an item without metadata" do
        it "should delegate directly to _base_pop" do
          result = base_item
          Resque.stub(:_base_pop) {|queue| result}
          Resque.pop(:test_queue).should == result
        end
      end

      context "metadata in the item retrieved from redis" do
        before do
          Resque.stub(:_base_pop){ base_item 'metadata' => {}}
        end

        it "should contain the hostname" do
          publishes(:dequeued) {|metadata| metadata[:hostname].should == `hostname`.chop}
          Resque.pop(:test_queue)
        end

        it "should contain the process id" do
          publishes(:dequeued) {|metadata| metadata[:process].should == $$}
          Resque.pop(:test_queue)
        end

        it "should contain an enqueued_time" do
          publishes(:dequeued) {|metadata| metadata[:time_in_queue].nil?.should == false}
          Resque.pop(:test_queue)
        end
      end
    end
  end
end
