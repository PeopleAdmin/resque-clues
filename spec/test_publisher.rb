class TestPublisher
  attr_reader :events

  def initialize
    @events = []
  end

  def publish(event_data)
        events << symbolized(event_data)
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
    @events[tail][:worker_class]
  end

  def args(tail=-1)
    @events[tail][:args]
  end

  private
  def symbolized(event_data)
    event_data.inject({}) {|memo, (k,v)| memo[k.to_sym] = v; memo}
  end
end
