require 'spec_helper'
require 'stringio'
require 'json'

describe Resque::Plugins::Clues::EventPublisher do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::EventPublisher) 
  end

  describe Resque::Plugins::Clues::EventPublisher::StandardOut do
    def verify_output(hash)
      STDOUT.should_receive(:puts).with(hash)
    end

    before do
      @publisher = Resque::Plugins::Clues::EventPublisher::StandardOut.new
    end

    it "should send enqueued event to STDOUT" do
      verify_output :event_type=>"enqueued", :queue=>:test_queue, :metadata=>{}, 
                    :worker_class=>"FooBar", :args=>["a", "b"]
      @publisher.enqueued(:test_queue, {}, "FooBar", "a", "b")
    end
  end
end
