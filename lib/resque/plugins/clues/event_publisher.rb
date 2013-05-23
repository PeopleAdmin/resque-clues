require 'pp'
require 'delegate'

module Resque
  attr_accessor :event_publisher

  module Plugins
    module Clues
      EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

      # Event publisher base class with shared logic between all publishers.
      class Base
        private
        def build_hash(event_type, timestamp, queue, metadata, worker_class, args)
          {
            event_type: event_type,
            timestamp: timestamp,
            queue: queue,
            metadata: metadata,
            worker_class: worker_class,
            args: args
          }
        end
      end

      # Event publisher that publishes events to standard output in a json
      # format.
      class StandardOutPublisher < Base
        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            puts(build_hash(event_type, timestamp, queue, metadata, klass, args))
          end
        end
      end

      # Event publisher that publishes events to a log file using ruby's
      # stdlib logger and an optional formatter..
      class LogPublisher < Base
        attr_reader :logger

        def initialize(log_path, formatter=nil)
          @logger = Logger.new(log_path)
          @logger.formatter = formatter || lambda{|s, d, p, msg| msg}
        end

        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            logger.info(build_hash(
              event_type, timestamp, queue, metadata, klass, args).to_json)
          end
        end
      end

      # A composite event publisher that groups several child publishers so
      # that events received are delegated to each of the children for
      # further processing.
      class CompositePublisher < SimpleDelegator
        def initialize
          super([])
        end

        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            each do |child|
              child.send(
                event_type, timestamp, queue, metadata, klass, *args
              ) rescue error(event_type, child)
            end
          end
        end

        private
        def error(event_type, child)
          p "Error processing #{event_type} in #{child}"
        end
      end
    end
  end
end
