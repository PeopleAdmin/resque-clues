require 'rspec'
require 'pry'
require 'resque-clues'
require 'test_worker'
require 'test_publisher'

def base_item(overrides={})
  {"class" => TestWorker.to_s, "args" => [1,2]}.merge!(overrides)
end

RSpec.configure do |config|
  config.before(:each) do
    reset_redis
  end
end

def reset_redis
  Resque.redis.select 15
  Resque.redis.flushdb
end

def verify_event(event_type, opts={event_index: -1})
  publisher.event_type(opts[:event_index]).should == event_type
  publisher.timestamp(opts[:event_index]).should_not be_empty
  publisher.queue(opts[:event_index]).should == :test_queue
  publisher.klass(opts[:event_index]).should == 'TestWorker'
  publisher.args(opts[:event_index]).should == [1, 2]
  yield(publisher.metadata(opts[:event_index])) if block_given?
end
