require 'rspec'
require 'pry'
require 'resque-clues'
require 'test_worker'

def base_item(overrides={})
  {"class" => TestWorker.to_s, "args" => [1,2]}.merge!(overrides)
end
