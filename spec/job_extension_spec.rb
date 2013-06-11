require 'spec_helper'

describe Resque::Plugins::Clues::JobExtension do
  def base_item(overrides={})
    {"class" => TestWorker.to_s, "args" => [1,2]}.merge!(overrides)
  end

  before do
    Resque::Plugins::Clues.event_publisher = nil
    @job = Resque::Job.new(:test_queue, base_item('clues_metadata' => {}))
  end

  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::JobExtension)
  end

  context "with clues not configured" do
    describe "#perform" do
      it "should delegate to original perform" do
        @job.should_receive(:_base_perform)
        @job.perform
      end
    end

    describe "#fail" do
      it "should delegate to original fail" do
        @job.should_receive(:_base_fail)
        @job.fail(Exception.new)
      end
    end
  end

  context "with clues configured" do
    let(:publisher) {TestPublisher.new}

    before do
      Resque::Plugins::Clues.event_publisher = publisher
    end

    def verify_event(event_type, opts={event_index: -1})
      publisher.event_type(opts[:event_index]).should == event_type
      publisher.timestamp(opts[:event_index]).should_not be_empty
      publisher.queue(opts[:event_index]).should == :test_queue
      publisher.klass(opts[:event_index]).should == 'TestWorker'
      publisher.args(opts[:event_index]).should == [1, 2]
      yield(publisher.metadata(opts[:event_index])) if block_given?
    end

    describe "#perform" do
      it "should publish a perform_started event" do
        @job.perform
        verify_event :perform_started, event_index: -2
      end

      it "should publish a perform_finished event that includes the time_to_perform" do
        @job.perform
        verify_event :perform_finished do |metadata|
          metadata['time_to_perform'].nil?.should == false
        end
      end
    end

    describe "#fail" do
      it "should publish a perform_failed event" do
        @job.fail(Exception.new)
        verify_event :failed
      end

      it "should delegate to original fail" do
        @job.should_receive(:_base_fail)
        @job.fail(Exception.new)
      end

      context "includes metadata in the perform_failed event that should" do
        it "should include the time_to_perform" do
          @job.fail(Exception.new)
          verify_event :failed do |metadata|
            metadata['time_to_perform'].nil?.should == false
          end
        end

        it "should include the exception class" do
          @job.fail(Exception.new)
          verify_event :failed do |metadata|
            metadata['exception'].should == Exception
          end
        end

        it "should include the exception message" do
          @job.fail(Exception.new('test'))
          verify_event :failed do |metadata|
            metadata['message'].should == 'test'
          end
        end

        it "should include the exception backtrace" do
          begin
            raise 'test'
          rescue => e
            @job.fail(e)
            verify_event :failed do |metadata|
              metadata['backtrace'].nil?.should == false
            end
          end
        end
      end
    end
  end
end
