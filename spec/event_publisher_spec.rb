require 'spec_helper'
require 'stringio'
require 'json'
require 'fileutils'

describe Resque::Plugins::Clues::EventPublisher do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::EventPublisher)
  end

  def publish_event_type(type)
    @publisher.send(type, :test_queue, {}, "FooBar", "a", "b")
  end

  describe Resque::Plugins::Clues::EventPublisher::StandardOut do
    def verify_output_for_event_type(type)
      STDOUT.should_receive(:puts).with event_type: type.to_s,
                                        queue: :test_queue,
                                        metadata: {},
                                        worker_class: "FooBar",
                                        args: ["a", "b"]
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

    it "should send failed event to STDOUT" do
      verify_output_for_event_type :failed
      publish_event_type :failed
    end

    it "should send destroyed event to STDOUT" do
      verify_output_for_event_type :destroyed
      publish_event_type :destroyed
    end
  end


  describe Resque::Plugins::Clues::EventPublisher::Log do
    def verify_event_written_to_log(event_type)
      last_event["event_type"].should == event_type.to_s
      last_event["queue"].should == 'test_queue'
      last_event["metadata"].should == {}
      last_event["worker_class"].should == "FooBar"
      last_event["args"].should == ["a", "b"]
    end

    def last_event
      JSON.parse(File.readlines(@log_path)[-1])
    end

    before do
      @log_path = File.join(Dir.tmpdir, "test_log.log")
      FileUtils.rm(@log_path)
      @publisher = Resque::Plugins::Clues::EventPublisher::Log.new(@log_path)
    end

    it "should write enqueued event to file" do
      publish_event_type :enqueued
      verify_event_written_to_log :enqueued
    end

    it "should write dequeued event to file" do
      publish_event_type :dequeued
      verify_event_written_to_log :dequeued
    end

    it "should write destroyed event to file" do
      publish_event_type :destroyed
      verify_event_written_to_log :destroyed
    end

    it "should write perform_started event to file" do
      publish_event_type :perform_started
      verify_event_written_to_log :perform_started
    end

    it "should write perform_finished event to file" do
      publish_event_type :perform_finished
      verify_event_written_to_log :perform_finished
    end

    it "should write failed event to file" do
      publish_event_type :failed
      verify_event_written_to_log :failed
    end
  end

  describe Resque::Plugins::Clues::EventPublisher::Composite do
    before do
      @publisher = Resque::Plugins::Clues::EventPublisher::Composite.new
      @publisher << Resque::Plugins::Clues::EventPublisher::StandardOut.new
      @publisher << Resque::Plugins::Clues::EventPublisher::StandardOut.new
    end

    def verify_event_delegated_to_children(event_type)
      @publisher.each do |child|
        child.should_receive(event_type).with(:test_queue, {}, "FooBar", "a", "b")
      end
    end

    it "should delegate enqueued event to children" do
      verify_event_delegated_to_children :enqueued
      publish_event_type :enqueued
    end

    it "should delegate dequeued event to children" do
      verify_event_delegated_to_children :dequeued
      publish_event_type :dequeued
    end

    it "should delegate destroyed event to children" do
      verify_event_delegated_to_children :destroyed
      publish_event_type :destroyed
    end

    it "should delegate perform_started event to children" do
      verify_event_delegated_to_children :perform_started
      publish_event_type :perform_started
    end

    it "should delegate perform_finished event to children" do
      verify_event_delegated_to_children :perform_finished
      publish_event_type :perform_finished
    end

    it "should delegate failed event to children" do
      verify_event_delegated_to_children :failed
      publish_event_type :failed
    end

    it "all children should be invoked when the first child throws an exception" do
      @publisher[0].stub(:enqueued) {raise 'YOU SHALL NOT PASS'}
      verify_event_delegated_to_children :enqueued 
      publish_event_type :enqueued
    end
  end
end
