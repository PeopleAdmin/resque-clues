require 'digest/md5'
require 'time'

module Resque
  module Plugins
    module Clues
      # Module capable of redefining the Resque#push and Resque#pop methods so
      # that:
      #
      # * metadata will be stored in redis.
      # * The metadata can be injected with arbitrary data by a configured item
      # preprocessor.
      # * That event data (including its metadata) will be published, provided
      # an event publisher has been configured.
      module QueueDecorator
        include Resque::Plugins::Clues::Util

        # push an item onto the queue.  If resque-clues is configured, this
        # will First create the metadata associated with the event and adds it
        # to the item.  This will include:
        #
        # * event_hash: a unique hash identifying the job, will be included
        # with other events arising from that job.
        # * hostname: the hostname of the machine where the event occurred.
        # * process:  The process id of the ruby process where the event
        # occurred.
        # * plus any items injected into the item via a configured
        # item_preprocessor.
        #
        # After that, an enqueued event is published and the original push
        # operation is invoked.
        #
        # queue:: The queue to push onto
        # orig:: The original item to push onto the queue.
        def push(queue, orig)
          return _base_push(queue, orig) unless clues_configured?
          item = symbolize(orig)
          item[:metadata] = {
            event_hash: event_hash,
            hostname: hostname,
            process: process,
            enqueued_time: Time.now.utc.to_f
          }
          if Resque::Plugins::Clues.item_preprocessor
            Resque::Plugins::Clues.item_preprocessor.call(queue, item)
          end
          event_publisher.enqueued(now, queue, item[:metadata], item[:class], *item[:args])
          _base_push(queue, item)
        end

        # pops an item off the head of the queue.  This will use the original
        # pop operation to get the item, then calculate the time in queue and
        # broadcast a dequeued event.
        #
        # queue:: The queue to pop from.
        def pop(queue)
          _base_pop(queue).tap do |orig|
            unless orig.nil?
              return orig unless clues_configured?
              item = prepare(orig) do |item|
                item[:metadata][:time_in_queue] = time_delta_since(item[:metadata][:enqueued_time])
                event_publisher.dequeued(now, queue, item[:metadata], item[:class], *item[:args])
              end
            end
          end
        end
      end

      # Module capable of redefining the Job#perform and Job#failed methods so
      # that they publish perform_started, perform_finished and failed events.
      module JobDecorator
        include Resque::Plugins::Clues::Util

        # Invoked when this module is included by a class.  Will redefine the
        # perform and failed methods on that class.
        #
        # klass:: The klass including this module.
        def self.included(klass)
          define_perform(klass)
          define_failed(klass)
        end

        private
        # (Re)defines the perform method so that it will broadcast a
        # perform_started event, invoke the original perform method, and
        # then broadcast a perform_finished event if no exceptions are
        # encountered.  The time to perform is calculated and included in
        # the metadata of the perform_finished event.
        #
        # klass:: The class to define the perform method on.
        def self.define_perform(klass) # :doc:
          klass.send(:define_method, :perform) do
            return _base_perform unless clues_configured?
            item = prepare(payload)
            event_publisher.perform_started(now, queue, item[:metadata], item[:class], *item[:args])
            @perform_started = Time.now
            _base_perform.tap do
              item[:metadata][:time_to_perform] = time_delta_since(@perform_started)
              event_publisher.perform_finished(now, queue, item[:metadata], item[:class], *item[:args])
            end
          end
        end

        # (Re)defines the failed method so that it will add time to perform,
        # exception, error message and backtrace data to the job's payload
        # metadata, then broadcast a failed event including that information.
        #
        # klass::  The class to define the failed method on.
        #
        def self.define_failed(klass) # :doc:
          klass.send(:define_method, :fail) do |exception|
            _base_fail(exception).tap do
              if clues_configured?
                item = prepare(payload)
                item[:metadata][:time_to_perform] = time_delta_since(@perform_started)
                item[:metadata][:exception] = exception.class
                item[:metadata][:message] = exception.message
                item[:metadata][:backtrace] = exception.backtrace
                event_publisher.failed(now, queue, item[:metadata], item[:class], *item[:args])
              end
            end
          end
        end
      end
    end
  end
end
