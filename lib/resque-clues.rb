require 'resque'
require 'resque/plugins/clues/util'
require 'resque/plugins/clues/queue_extension'
require 'resque/plugins/clues/job_extension'
require 'resque/plugins/clues/event_publisher'
require 'resque/plugins/clues/version'

module Resque
  module Plugins
    module Clues
      class << self
        attr_accessor :item_preprocessor
        attr_accessor :event_marshaller

        def configured?
          !event_publisher.nil?
        end

        def enable!
          # Patch resque to support event broadcasting.
          Resque.send(:extend, Resque::Plugins::Clues::QueueExtension)
          Resque::Job.send(:include, Resque::Plugins::Clues::JobExtension)
          Resque.instance_exec do
            alias :_base_push :push
            alias :_base_pop :pop

            def push(queue, item)
              _clues_push(queue, item)
            end

            def pop(queue)
              _clues_pop(queue)
            end
          end

          Resque::Job.class_exec do
            alias :_base_perform :perform
            alias :_base_fail :fail

            def perform
              _clues_perform
            end

            def fail(exception)
              _clues_fail(exception)
            end
          end
        end
      end
    end
  end
end

# Constructs a string event for the passed args.  Delegates to the
# Resque::Plugins::Clues.event_marshaller proc/lambda to do this.  The
# default version will simply marshall the args to a JSON object.
#
# event_type:: enqueued, dequeued, perform_started, perform_finished or
# failed.
# timestamp:: the time the event occurred.
# queue:: the queue the job was in
# metadata:: metadata for the job, such as host, process, etc...
# worker_class:: the worker job class
# args:: arguments passed to the perform_method.
Resque::Plugins::Clues.event_marshaller =
  lambda do |event_data|
    event = MultiJson.encode({
      event_type: event_data[:event_type],
      timestamp: event_data[:timestamp],
      queue: event_data[:queue],
      metadata: event_data[:metadata],
      worker_class: event_data[:worker_class],
      args: event_data[:args]
    })
    "#{event}\n"
  end

Resque::Plugins::Clues.enable!
