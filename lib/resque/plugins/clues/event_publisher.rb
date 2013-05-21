require 'pp'

module Resque
  module Plugins
    module Clues
      module EventPublisher
        EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

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

        class StandardOut < Base
          EVENT_TYPES.each do |event_type|
            define_method(event_type) do |queue, metadata, klass, *args|
              puts(build_hash(event_type, queue, metadata, klass, args))
            end
          end
        end

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
