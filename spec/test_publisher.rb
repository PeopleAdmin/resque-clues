class TestPublisher
  attr_reader :event_type, :timestamp, :queue, :metadata, :klass, :args
  def publish(event_type, timestamp, queue, metadata, klass, *args)
    @event_type = event_type
    @timestamp = timestamp
    @queue = queue
    @metadata = metadata
    @klass = klass
    @args = args
  end
end
