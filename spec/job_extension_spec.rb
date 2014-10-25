require 'spec_helper'

describe Resque::Plugins::Clues::JobExtension do
  before do
    Resque::Plugins::Clues.event_publisher = nil
  end
  let(:base_item) do
    {
      "class" => TestWorker.to_s,
      "args" => [1,2],
      "clues_metadata" => {}
    }
  end
  let(:job) { Resque::Job.new(:test_queue, base_item) }

  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::JobExtension)
  end

  context "with clues not configured" do
    describe "#perform" do
      it "should delegate to original perform" do
        job.should_receive(:_base_perform)
        job.perform
      end
    end

    describe "#fail" do
      it "should delegate to original fail" do
        job.should_receive(:_base_fail)
        job.fail(Exception.new)
      end
    end
  end

  context "with clues configured" do
    let(:publisher) {TestPublisher.new}

    before do
      Resque::Plugins::Clues.event_publisher = publisher
    end

    describe "#perform" do
      it "should publish a perform_started event" do
        job.perform
        verify_event :perform_started, event_index: -2
      end

      it "should publish a perform_finished event that includes the time_to_perform" do
        job.perform
        verify_event :perform_finished do |metadata|
          expect(metadata['_time_to_perform']).to_not be_nil
          expect(metadata['time_to_perform']).to_not be_nil
        end
      end

      context "when encountering a job that modifies clues metadata at runtime" do
        let(:base_item) do
          {
            "class" => InjectingWorker.to_s,
            "args" => [{'injection' => true}],
            "clues_metadata" => {}
          }
        end

        it "should publish a perfor_finished event that includes the modified metadta" do
          job.perform
          expect(publisher.events.last[:metadata]["injection"]).to eq(true)
        end
      end
    end

    describe "#fail" do
      it "should publish a perform_failed event" do
        job.fail(Exception.new)
        verify_event :failed
      end

      it "should delegate to original fail" do
        job.should_receive(:_base_fail)
        job.fail(Exception.new)
      end

      context "when encountering a job that modifies clues metadata at runtime then fails" do
        before {Resque::Plugins::Clues::Runtime.clues_metadata = {}}
        let(:clues_metadata) {Resque::Plugins::Clues::Runtime.clues_metadata}
        it "should publish a perform_finished event that includes the modified metadta" do
          clues_metadata[:injection] = true
          job.fail(Exception.new)
          expect(publisher.events.last[:metadata]["injection"]).to eq(true)
        end
      end

      context "includes metadata in the perform_failed event that should" do
        it "should include the time_to_perform" do
          job.fail(Exception.new)
          verify_event :failed do |metadata|
            expect(metadata['_time_to_perform']).to_not be_nil
            expect(metadata['time_to_perform']).to_not be_nil
          end
        end

        it "should include the exception class" do
          job.fail(Exception.new)
          verify_event :failed do |metadata|
            expect(metadata['_exception']).to eq('Exception')
            expect(metadata['exception']).to eq('Exception')
          end
        end

        it "should include the exception message" do
          job.fail(Exception.new('test'))
          verify_event :failed do |metadata|
            expect(metadata['_message']).to eq("test")
            expect(metadata['message']).to eq("test")
          end
        end

        it "should include the exception backtrace" do
          begin
            raise 'test'
          rescue => e
            job.fail(e)
            verify_event :failed do |metadata|
              expect(metadata['_backtrace']).to_not be_nil
              expect(metadata['backtrace']).to_not be_nil
            end
          end
        end
      end
    end
  end
end
