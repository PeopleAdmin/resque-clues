require 'pp'

module Resque
  module Plugins
    module Clues
      # Contains event publisher classes that can be used to broadcast the
      # following Resque job related events:
      #
      # enqueued:: When any job enters a queue
      # dequeued:: When any job leaves a queue for execution
      # destroyed:: When any job is discarded from a queue
      # perform_started:: When any job is is about to be performed.
      # perform_finished:: When any job has successfully finished performing
      # failed:: When an exception was raised while performing a job.
      module EventPublisher
        EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

        # Event publisher base class with shared logic between all publishers.
        class Base
          private
          def build_hash(event_type, queue, metadata, worker_class, args)
            {
              event_type: event_type,
              queue: queue,
              metadata: metadata,
              worker_class: worker_class,
              args: args
            }
          end
        end

        # Event publisher that publishes events to standard output in a json
        # format.
        class StandardOut < Base
          EVENT_TYPES.each do |event_type|
            define_method(event_type) do |queue, metadata, klass, *args|
              puts(build_hash(event_type, queue, metadata, klass, args))
            end
          end
        end

        # Event publisher that publishes events to a log file using ruby's
        # stdlib logger and an optional formatter..
        class Log < Base
          attr_reader :logger

          def initialize(log_path, formatter=nil)
            @logger = Logger.new(log_path)
            @logger.formatter = formatter || lambda{|s, d, p, msg| msg}
          end

          EVENT_TYPES.each do |event_type|
            define_method(event_type) do |queue, metadata, klass, *args|
              logger.info(build_hash(event_type, queue, metadata, klass, args).to_json)
            end
          end
        end

        # A composite event publisher that groups several child publishers so
        # that events received are delegated to each of the children for
        # further processing.
        class Composite < SimpleDelegator
          def initialize
            super([])
          end

          EVENT_TYPES.each do |event_type|
            define_method(event_type) do |queue, metadata, klass, *args|
              each do |child|
                child.send(event_type, queue, metadata, klass, *args) rescue error(event_type, child)
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
end
