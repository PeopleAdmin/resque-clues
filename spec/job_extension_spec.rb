require 'spec_helper'
require 'set'

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
    def publishes(opts={})
      opts.keys.each{|key| @events_not_received << key}
      @events_not_received.size.should_not == 0
      Resque::Plugins::Clues.event_publisher.should_receive(:publish).at_least(:once)
      Resque::Plugins::Clues.event_publisher.stub(:publish) do |type, time, queue, metadata, klass, *args|
        @events_not_received.delete(type)
        time.nil?.should == false
        queue.should == :test_queue
        klass.should == 'TestWorker'
        args.should == [1,2]
        metadata['hostname'].should == `hostname`.strip
        metadata['process'].should == $$
        opts[type].call(metadata) if opts[type]
      end
    end

    before do
      Resque::Plugins::Clues.event_publisher = Resque::Plugins::Clues::StandardOutPublisher.new
      @events_not_received = Set.new([])
    end

    after do
      @events_not_received.size.should == 0 
    end

    describe "#perform" do
      it "should publish a perform_started event" do
        publishes perform_started: nil
        @job.perform
      end

      it "should publish a perform_finished event that includes the time_to_perform" do
        publishes(perform_finished: lambda do |metadata|
          metadata['time_to_perform'].nil?.should == false
        end)
        @job.perform
      end
    end

    describe "#fail" do
      it "should publish a perform_failed event" do
        publishes failed: nil
        @job.fail(Exception.new)
      end

      it "should delegate to original fail" do
        @job.should_receive(:_base_fail)
        @job.fail(Exception.new)
      end

      context "includes metadata in the perform_failed event that should" do
        it "should include the time_to_perform" do
          publishes(failed: lambda do |metadata|
            metadata['time_to_perform'].nil?.should == false
          end)
          @job.fail(Exception.new)
        end

        it "should include the exception class" do
          publishes(failed: lambda do |metadata|
            metadata['exception'].should == Exception
          end)
          @job.fail(Exception.new)
        end

        it "should include the exception message" do
          publishes(failed: lambda do |metadata|
            metadata['message'].should == 'test'
          end)
          @job.fail(Exception.new('test'))
        end

        it "should include the exception backtrace" do
          begin
            raise 'test'
          rescue => e
            publishes(failed: lambda do |metadata|
              metadata['backtrace'].nil?.should == false
            end)
            @job.fail(e)
          end
        end
      end
    end
  end
end
