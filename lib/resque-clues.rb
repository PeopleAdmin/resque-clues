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
  lambda do |event_type, timestamp, queue, metadata, worker_class, args|
    event = MultiJson.encode({
      event_type: event_type,
      timestamp: timestamp,
      queue: queue,
      metadata: metadata,
      worker_class: worker_class,
      args: args
    })
    "#{event}\n"
  end

# Patch resque to support event broadcasting.
Resque.send(:alias_method, :_base_push, :push)
Resque.send(:alias_method, :_base_pop, :pop)
Resque.send(:extend, Resque::Plugins::Clues::QueueExtension)
Resque::Job.send(:alias_method, :_base_perform, :perform)
Resque::Job.send(:alias_method, :_base_fail, :fail)
Resque::Job.send(:include, Resque::Plugins::Clues::JobExtension)
