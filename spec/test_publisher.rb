class TestPublisher
  attr_reader :events

  def initialize
    @events = []
  end

  def publish(event_type, timestamp, queue, metadata, klass, *args)
    events << {
      event_type: event_type,
      timestamp: timestamp,
      queue: queue,
      metadata: metadata,
      klass: klass,
      args: args
    }
  end

  def event_type(tail=-1)
    @events[tail][:event_type]
  end

  def timestamp(tail=-1)
    @events[tail][:timestamp]
  end

  def queue(tail=-1)
    @events[tail][:queue]
  end

  def metadata(tail=-1)
    @events[tail][:metadata]
  end

  def klass(tail=-1)
    @events[tail][:klass]
  end

  def args(tail=-1)
    @events[tail][:args]
  end
end
