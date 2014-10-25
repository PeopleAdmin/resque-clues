require 'spec_helper'
require 'stringio'
require 'timeout'
require 'json'

# Setting $TESTING to true will cause Resque to not fork a child to perform the
# job, doing all the work within the test process and allowing us to test
# results for all aspects of the job performance.
$TESTING = true

class DummyWorker
  @queue = :test_queue

  def self.invoked?
    @invoked
  end

  def self.reset!
    @invoked = false
  end

  def self.perform(msg)
    @invoked = true
  end
end

class FailingDummyWorker
  @queue = :test_queue

  def self.perform(msg)
    raise msg
  end
end

describe 'end-to-end integration' do
  before(:each) do
    DummyWorker.reset!
    @stream = StringIO.new
    @worker = Resque::Worker.new(:test_queue)
    #@worker.very_verbose = true
    Resque::Plugins::Clues.event_publisher = Resque::Plugins::Clues::StreamPublisher.new(@stream)
  end

  def stream_size
    @stream.rewind
    @stream.readlines.size
  end

  def enqueue_then_verify(klass, *args, &block)
    Resque.enqueue(klass, *args)
    work_and_verify(&block)
  end

  def work
    timeout(0.2){ @worker.work(0.1) } rescue nil
  end

  def work_and_verify(&block)
    work
    @stream.rewind
    block.call(@stream.readlines.map{|line| MultiJson.decode(line)})
  end

  def verify_event(event, type, klass, *args)
    event["worker_class"].should == klass.to_s
    event["args"].should == args
    event["event_type"].should == type.to_s
    event["timestamp"].should_not be_nil
    event["metadata"]["_event_hash"].should_not be_nil
    event["metadata"]["_hostname"].should == `hostname`.strip
    event["metadata"]["_process"].should == $$
    event["metadata"]["event_hash"].should_not be_nil
    event["metadata"]["hostname"].should == `hostname`.strip
    event["metadata"]["process"].should == $$
    yield(event) if block_given?
  end

  context "for job that finishes normally" do
    it "should publish enqueued, dequeued, perform_started and perform_finished events" do
      enqueue_then_verify(DummyWorker, 'test') do |events|
        events.size.should == 4
        verify_event(events[0], :enqueued, DummyWorker, "test")
        verify_event(events[1], :dequeued, DummyWorker, "test") do |event|
          event["metadata"]["_time_in_queue"].should_not be_nil
          event["metadata"]["time_in_queue"].should_not be_nil
        end
        verify_event(events[2], :perform_started, DummyWorker, "test")
        verify_event(events[3], :perform_finished, DummyWorker, "test") do |event|
          event["metadata"]["_time_to_perform"].should_not be_nil
          event["metadata"]["time_to_perform"].should_not be_nil
        end
      end
    end
  end

  context "for job that fails" do
    it "should publish enqueued, dequeued, perform_started and failed events" do
      enqueue_then_verify(FailingDummyWorker, 'test') do |events|
        events.size.should == 4
        verify_event(events[0], :enqueued, FailingDummyWorker, "test")
        verify_event(events[1], :dequeued, FailingDummyWorker, "test") do |event|
          event["metadata"]["_time_in_queue"].should_not be_nil
          event["metadata"]["time_in_queue"].should_not be_nil
        end
        verify_event(events[2], :perform_started, FailingDummyWorker, "test")
        verify_event(events[3], :failed, FailingDummyWorker, "test") do |event|
          event["metadata"]["_time_to_perform"].should_not be_nil
          event["metadata"]["_exception"].should == RuntimeError.to_s
          event["metadata"]["_message"].should == 'test'
          event["metadata"]["_backtrace"].should_not be_nil
          event["metadata"]["time_to_perform"].should_not be_nil
          event["metadata"]["exception"].should == RuntimeError.to_s
          event["metadata"]["message"].should == 'test'
          event["metadata"]["backtrace"].should_not be_nil
        end
      end
    end
  end

  context "for job enqueued prior to use of resque-clues gem" do
    def enqueue_unpatched(worker, *args)
      unpatch_resque
      begin
        Resque.enqueue(worker, *args)
      ensure
        repatch_resque
      end
    end

    context "job that performs normally" do
      before do
        enqueue_unpatched(DummyWorker, "test")
      end

      it "should succeed without failures" do
        work
        DummyWorker.invoked?.should == true
        Resque::Failure.all.should == nil
      end
    end

    context "job failures" do
      before do
        enqueue_unpatched(FailingDummyWorker, "test")
      end

      it "should report failure normally" do
        work
        Resque::Failure.count.should == 1
      end
    end
  end

  context "where job enqueued with resque-clues gem but worker performing job is not" do
    def unpatch_and_work
      unpatch_resque
      work
      yield if block_given?
    ensure
      repatch_resque
    end

    context "for job that performs normally" do
      before {Resque.enqueue DummyWorker, "test"}

      it "should succeed without failures" do
        unpatch_and_work {Resque::Failure.all.should == nil}
      end
    end

    context "for job failures" do
      before {Resque.enqueue FailingDummyWorker, "test"}

      it "should report failure normally" do
        unpatch_and_work {Resque::Failure.count.should == 1}
      end
    end
  end

  context "Resque internals assumptions" do
    describe "Resque#push" do
      it "should receive item with class and args as symbols" do
        received_item = nil
        Resque.stub(:push) {|queue, item| received_item = item}
        Resque.enqueue(DummyWorker, 'test')
        received_item[:class].should == "DummyWorker"
        received_item[:args].should == ['test']
      end
    end
  end
end
