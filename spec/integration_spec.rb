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

  def self.perform(msg)
    # do nothing
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
    @stream = StringIO.new
    Resque.redis.flushall
    @worker = Resque::Worker.new(:test_queue)
    Resque::Plugins::Clues.event_publisher = Resque::Plugins::Clues::StreamPublisher.new(@stream)
  end

  def stream_size
    @stream.rewind
    @stream.readlines.size
  end

  def enqueue_then_verify(klass, *args, &block)
    timeout(0.2) do
      Resque.enqueue(klass, *args)
      @worker.work(0.1)
    end
    @stream.rewind
    block.call(@stream.readlines.map{|line| JSON.parse(line)})
  end

  def verify_event(event, type, klass, *args)
    event["worker_class"].should == klass.to_s
    event["args"].should == args
    event["event_type"].should == type.to_s
    event["timestamp"].should_not be_nil
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
          event["metadata"]["time_in_queue"].should_not be_nil
        end
        verify_event(events[2], :perform_started, DummyWorker, "test")
        verify_event(events[3], :perform_finished, DummyWorker, "test") do |event|
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
          event["metadata"]["time_in_queue"].should_not be_nil
        end
        verify_event(events[2], :perform_started, FailingDummyWorker, "test")
        verify_event(events[3], :failed, FailingDummyWorker, "test") do |event|
          event["metadata"]["time_to_perform"].should_not be_nil
          event["metadata"]["exception"].should == RuntimeError.to_s
          event["metadata"]["message"].should == 'test'
          event["metadata"]["backtrace"].should_not be_nil
        end
      end
    end
  end
end
