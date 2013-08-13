require 'spec_helper'

describe Resque::Plugins::Clues::FilterPublisher do
  before do
    @publisher = Resque::Plugins::Clues::FilterPublisher.new
    @current_time = Time.now.utc.iso8601
  end

  it "should publish events to events and filtered_events with no filters applied" do
    publish_event_type(:enqueue, "email")
    verify_event_published(:enqueue, "email")
    verify_filtered_event_published(:enqueue, "email")
  end


  it "should filter currently published events when filter applied and push filters to filter list" do
    publish_event_type(:NoOpWorker, "email")
    publish_event_type(:NoOpWorker, "test_queue_1")
    publish_event_type(:NoOpWorker, "test_queue_2")
    @publisher.filter("queue == 'email'")
    @publisher.filters.length.should == 1
    @publisher.filtered_events.length.should == 1
    verify_filtered_event_published(:NoOpWorker, "email")
  end

  it "should allow filters call that is empty and perform a no-op" do
    publish_event_type(:NoOpWorker, "email")
    publish_event_type(:NoOpWorker, "test_queue_1")
    publish_event_type(:NoOpWorker, "test_queue_2")
    @publisher.filter()
    @publisher.filters.length.should == 0
    @publisher.filtered_events.length.should == 3
    verify_filtered_event_published(:NoOpWorker, "test_queue_2")
  end

  it "should remove all filters on events and filters list when filters are cleared" do
    publish_event_type(:NoOpWorker, "email")
    publish_event_type(:NoOpWorker, "test_queue_1")
    publish_event_type(:NoOpWorker, "test_queue_2")
    @publisher.filter("queue == 'email'")
    @publisher.clear_filters
    @publisher.filters.length.should == 0
    @publisher.filtered_events.length.should == 3
  end

  it "should apply filters to incoming events" do
    publish_event_type(:NoOpWorker, "email")
    @publisher.filter("queue == 'email'")
    publish_event_type(:NoOpWorker, "test_queue_1")
    @publisher.filtered_events.length.should == 1
    publish_event_type(:NoOpWorker, "email")
    @publisher.filtered_events.length.should == 2
    @publisher.events.length.should == 3
  end

  it "should be able to clear filters and not continue applying to incoming events" do
    publish_event_type(:NoOpWorker, "email")
    @publisher.filter("queue == 'email'")
    publish_event_type(:NoOpWorker, "test_queue_1")
    @publisher.clear_filters
    publish_event_type(:NoOpWorker, "test_queue_1")
    @publisher.filtered_events.length.should == 3
    verify_filtered_event_published(:NoOpWorker, "test_queue_1")
  end

  it "should be able to chain filters during calls" do
    publish_event_type(:enqueue, "email")
    publish_event_type(:enqueue, "test_queue1")
    publish_event_type(:dequeue, "test_queue1")
    @publisher.filter("queue == 'test_queue1'").filter('event_type == :dequeue')
    @publisher.filtered_events.length.should == 1

  end

  it "should be able to apply several separate filters " do
    publish_event_type(:enqueue, "email")
    publish_event_type(:enqueue, "test_queue1")
    publish_event_type(:dequeue, "test_queue1")
    @publisher.filter("queue == 'test_queue1'")
    @publisher.filter('event_type == :dequeue')
    @publisher.filtered_events.length.should == 1

  end

end


private
def publish_event_type(type, queue)
  @publisher.publish(type, @current_time, queue, {}, "FooBar", "a", "b")
end

def verify_event_published(type, queue)
  event = @publisher.events.last
  event.event_type.should == type
  event.timestamp.should == @current_time.to_s
  event.queue.should == queue
  event.metadata.should == {}
  event.klass.should == "FooBar"
  event.args.should == ["a", "b"]
end

def verify_filtered_event_published(type, queue)
  event = @publisher.filtered_events.last
  event.event_type.should == type
  event.timestamp.should == @current_time.to_s
  event.queue.should == queue
  event.metadata.should == {}
  event.klass.should == "FooBar"
  event.args.should == ["a", "b"]
end
