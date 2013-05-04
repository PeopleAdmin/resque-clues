require 'spec_helper'
require 'stringio'
require 'json'

describe Resque::Plugins::Clues::EventPublisher do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::EventPublisher) 
  end

  describe Resque::Plugins::Clues::EventPublisher::StandardOut do
    def verify_output_for_event_type(type)
      STDOUT.should_receive(:puts).with event_type: type.to_s,
                                        queue: :test_queue,
                                        metadata: {},
                                        worker_class: "FooBar",
                                        args: ["a", "b"]
    end

    def publish_event_type(type)
      @publisher.send(type, :test_queue, {}, "FooBar", "a", "b")
    end

    before do
      @publisher = Resque::Plugins::Clues::EventPublisher::StandardOut.new
    end

    it "should send enqueued event to STDOUT" do
      verify_output_for_event_type :enqueued
      publish_event_type :enqueued
    end

    it "should send dequeued event to STDOUT" do
      verify_output_for_event_type :dequeued
      publish_event_type :dequeued
    end

    it "should send perform_started event to STDOUT" do
      verify_output_for_event_type :perform_started
      publish_event_type :perform_started
    end

    it "should send perform_finished event to STDOUT" do
      verify_output_for_event_type :perform_finished
      publish_event_type :perform_finished
    end
  end
end
