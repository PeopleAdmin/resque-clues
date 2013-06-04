require 'pp'
require 'delegate'

module Resque
  module Plugins
    module Clues
      class << self
        attr_accessor :event_publisher
      end
      EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

      # Event publisher base class with shared logic between all publishers.
      class BasePublisher
        private
        # Builds a hash for the passed data.
        #
        # event_type:: enqueued, dequeued, perform_started, perform_finished or
        # failed.
        # timestamp:: the time the event occurred.
        # queue:: the queue the job was in
        # metadata:: metadata for the job, such as host, process, etc...
        # worker_class:: the worker job class
        # args:: arguments passed to the perform_method.
        def build_hash(event_type, timestamp, queue, metadata, worker_class, args) # :doc:
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

      # Event publisher that publishes events to a file-like stream in a JSON
      # format.  Each message is punctuated with a terminus character, which
      # defaults to newline ("\n")
      class StreamPublisher < BasePublisher
        attr_reader :stream, :terminus

        # Creates a new StreamPublisher that writes to the passed stream,
        # terminating each event with the terminus.
        #
        # stream:: The file-like stream to write events to.
        # terminus:: The character to write between events.  Defaults to "\n"
        def initialize(stream, terminus="\n")
          @stream = stream
          @terminus = terminus
        end

        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            event = build_hash(event_type, timestamp, queue, metadata, klass, args)
            stream.write("#{event.to_json}#{terminus}")
          end
        end
      end

      # Event publisher that publishes events to standard output in a json
      # format.
      class StandardOutPublisher < StreamPublisher
        def initialize
          super(STDOUT)
        end
      end

      # Event publisher that publishes events to a log file using ruby's
      # stdlib logger and an optional formatter..
      class LogPublisher < BasePublisher
        attr_reader :logger

        # Creates a new LogPublisher that writes events to a log file at the
        # specified log_path, using an optional formatter.  The default format
        # will simply be the event in a json format, one per line.
        #
        # log_path:: The path to the log file.
        # formatter:: A lambda formatter for log messages.  Defaults to writing
        # one event per line.  See
        # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger/Formatter.html
        def initialize(log_path, formatter=nil)
          @logger = Logger.new(log_path)
          @logger.formatter = formatter || lambda {|severity, time, program, msg| "#{msg}\n"}
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
