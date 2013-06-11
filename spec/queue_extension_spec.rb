require 'spec_helper'

describe Resque::Plugins::Clues::QueueExtension do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::QueueExtension)
  end

  it "should expose original push method as _base_push" do
    Resque.respond_to?(:_base_push).should == true
  end

  it "should expose original pop method as _base_pop" do
    Resque.respond_to?(:_base_pop).should == true
  end

  context "with clues not configured" do
    before {Resque::Plugins::Clues.event_publisher = nil}
    describe "#push" do
      it "should delegate directly to original Resque push method" do
        Resque.should_receive(:_base_push).with(:test_queue, {})
        Resque.push(:test_queue, {})
      end
    end

    describe "#pop" do
      it "should delegate directly to original Resque pop method" do
        Resque.stub(:_base_pop) do |queue|
          queue.should == :test_queue
          {}
        end
        Resque.pop(:test_queue).should == {}
      end
    end
  end

  context "with clues properly configured" do
    let(:publisher) {TestPublisher.new}

    before do
      Resque::Plugins::Clues.event_publisher = publisher
    end

    describe "#push" do
      def base_item(overrides={})
        {:class => TestWorker.to_s, :args => [1,2]}.merge!(overrides)
      end

      it "should invoke _base_push with a queue and item args and return the result" do
        Resque.should_receive(:_base_push)
        Resque.push(:test_queue, base_item)
      end

      context "adds metadata to item stored in redis that" do
        it "should contain an event_hash identifying the job entering the queue" do
          Resque.push(:test_queue, base_item)
          verify_event :enqueued do |metadata|
            metadata['event_hash'].nil?.should == false
          end
        end

        it "should contain the host's hostname" do
          Resque.push(:test_queue, base_item)
          verify_event :enqueued do |metadata|
            metadata['hostname'].should == `hostname`.strip
          end
        end

        it "should contain the process id" do
          Resque.push(:test_queue, base_item)
          verify_event :enqueued do |metadata|
            metadata['process'].should == $$
          end
        end

        it "should allow an item_preprocessor to inject arbitrary data" do
          Resque::Plugins::Clues.item_preprocessor = proc {|queue, item| item['clues_metadata']['employer_id'] = 1}
          Resque.push(:test_queue, base_item)
          verify_event :enqueued do |metadata|
            metadata['employer_id'].should == 1
          end
        end
      end
    end

    describe "#pop" do
      def base_item(overrides={})
        {'class' => TestWorker.to_s, 'args' => [1,2]}.merge!(overrides)
      end

      it "should invoke _base_pop with a queue arg and return the result" do
        Resque.should_receive(:_base_pop)
        Resque.pop(:test_queue)
      end

      context "when nothing is in the queue" do
        it "should not die horribly" do
          expect{Resque.pop(:test_queue)}.to_not raise_error
        end
      end

      context "when retrieving an item without metadata" do
        it "should delegate directly to _base_pop" do
          result = base_item 'clues_metadata' => {}
          Resque.stub(:_base_pop) {|queue| result}
          Resque.pop(:test_queue).should == result
        end
      end

      context "metadata in the item retrieved from redis" do
        before do
          Resque.stub(:_base_pop){ base_item 'clues_metadata' => {}}
        end

        it "should contain the hostname" do
          Resque.pop(:test_queue)
          verify_event :dequeued do |metadata|
            metadata['hostname'].should == `hostname`.chop
          end
        end

        it "should contain the process id" do
          Resque.pop(:test_queue)
          verify_event :dequeued do |metadata|
            metadata['process'].should == $$
          end
        end

        it "should contain an enqueued_time" do
          Resque.pop(:test_queue)
          verify_event :dequeued do |metadata|
            metadata['time_in_queue'].nil?.should == false
          end
        end
      end
    end
  end
end
