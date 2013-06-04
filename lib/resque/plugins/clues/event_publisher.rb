require 'pp'
require 'delegate'

module Resque
  module Plugins
    module Clues
      CLUES = Resque::Plugins::Clues
      class << self
        attr_accessor :event_publisher
      end
      CLUES = Resque::Plugins::Clues
      EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

      # Event publisher that publishes events to a file-like stream in a JSON
      # format.  Each message is punctuated with a terminus character, which
      # defaults to newline ("\n")
      class StreamPublisher
        attr_reader :stream

        # Creates a new StreamPublisher that writes to the passed stream,
        # terminating each event with the terminus.
        #
        # stream:: The file-like stream to write events to.
        def initialize(stream)
          @stream = stream
        end

        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            event = CLUES.event_marshaller.call(event_type, timestamp, queue, metadata, klass, args)
            stream.write("#{event}")
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
      class LogPublisher
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
          @logger.formatter = formatter || lambda {|severity, time, program, msg| msg}
        end

        EVENT_TYPES.each do |event_type|
          define_method(event_type) do |timestamp, queue, metadata, klass, *args|
            logger.info(CLUES.event_marshaller.call(
              event_type, timestamp, queue, metadata, klass, args))
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
