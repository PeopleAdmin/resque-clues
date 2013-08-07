      # Event publisher that publishes events to a configurable indexers for datam-ining..
      class IndexerPublisher
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
        def publish(event_type, timestamp, queue, metadata, klass, *args)

        end
      end