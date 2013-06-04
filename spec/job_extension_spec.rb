require 'spec_helper'

def base_item(overrides={})
  {"class" => TestWorker.to_s, "args" => [1,2]}.merge!(overrides)
end

describe Resque::Plugins::Clues::JobExtension do
  before do
    Resque::Plugins::Clues.event_publisher = nil
    @job = Resque::Job.new(:test_queue, base_item(metadata: {}))
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
    def publishes(evt_type)
      Resque::Plugins::Clues.event_publisher.should_receive(evt_type)
      Resque::Plugins::Clues.event_publisher.stub(evt_type) do |time, queue, metadata, klass, *args|
        time.nil?.should == false
        queue.should == :test_queue
        klass.should == 'TestWorker'
        args.should == [1,2]
        metadata[:hostname].should == `hostname`.strip
        metadata[:process].should == $$
        yield(metadata) if block_given?
      end
    end

    before do
      Resque::Plugins::Clues.event_publisher = Resque::Plugins::Clues::StandardOutPublisher.new
    end

    describe "#perform" do
      it "should publish a perform_started event" do
        publishes(:perform_started)
        @job.perform
      end

      it "should publish a perform_finished event that includes the time_to_perform" do
        publishes(:perform_finished) do |metadata|
          metadata[:time_to_perform].nil?.should == false
        end
        @job.perform
      end
    end

    describe "#fail" do
      it "should publish a perform_failed event" do
        publishes(:failed)
        @job.fail(Exception.new)
      end

      it "should delegate to original fail" do
        @job.should_receive(:_base_fail)
        @job.fail(Exception.new)
      end

      context "includes metadata in the perform_failed event that should" do
        it "should include the time_to_perform" do
          publishes(:failed) do |metadata|
            metadata[:time_to_perform].nil?.should == false
          end
          @job.fail(Exception.new)
        end

        it "should include the exception class" do
          publishes(:failed) do |metadata|
            metadata[:exception].should == Exception
          end
          @job.fail(Exception.new)
        end

        it "should include the exception message" do
          publishes(:failed) do |metadata|
            metadata[:message].should == 'test'
          end
          @job.fail(Exception.new('test'))
        end

        it "should include the exception backtrace" do
          begin
            raise 'test'
          rescue => e
            publishes(:failed) do |metadata|
              metadata[:backtrace].nil?.should == false
            end
            @job.fail(e)
          end
        end
      end
    end
  end
end
