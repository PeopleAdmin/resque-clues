require 'pp'
require 'delegate'

module Resque
  module Plugins
    module Clues
      class << self
        attr_accessor :event_publisher
      end
      EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

      # No op publisher, can be useful for testing/ensuring metadata injected
      # even if you don't plan on pushing it anywhere.
      class NoOpPublisher
        define_method(:publish) {|evt_data|}
      end

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

        # Publishes an event to the stream.
        def publish(event_data)
          event = Clues.event_marshaller.call(event_data)
          stream.write(event)
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

        # Publishes an event to the log.
        def publish(event_data)
          logger.info(Clues.event_marshaller.call(event_data))
        end
      end

      # A composite event publisher that groups several child publishers so
      # that events received are delegated to each of the children for
      # further processing.
      class CompositePublisher < SimpleDelegator
        def initialize
          super([])
        end

        # Invokes publish on each child publisher for them to publish the event
        # in their own way.
        def publish(event_data)
          each do |child|
            child.publish(event_data) rescue error(event_type, child)
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
