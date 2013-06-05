require 'rspec'
require 'pry'
require 'resque-clues'
require 'test_worker'

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
