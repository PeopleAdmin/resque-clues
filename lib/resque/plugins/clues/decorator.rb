require 'digest/md5'
require 'time'

module Resque
  module Plugins
    module Clues
      module QueueDecorator
        include Resque::Plugins::Clues::Util
        include Resque::Plugins::Clues::EventHashable
        attr_accessor :item_preprocessor

        def push(queue, orig)
          return _base_push(queue, orig) unless clues_configured?
          item = symbolize(orig)
          item[:metadata] = {
            event_hash: event_hash,
            hostname: hostname,
            process: process,
            enqueued_time: Time.now.utc.to_f
          }
          item_preprocessor.call(queue, item) if item_preprocessor
          event_publisher.enqueued(now, queue, item[:metadata], item[:class], *item[:args])
          _base_push(queue, item)
        end

        def pop(queue)
          _base_pop(queue).tap do |orig|
            item = symbolize(orig)
            return orig unless clues_configured? and item[:metadata]
            item[:metadata][:hostname] = hostname
            item[:metadata][:process] = $$
            item[:metadata][:time_in_queue] = time_delta_since(item[:metadata][:enqueued_time])
            event_publisher.dequeued(now, queue, item[:metadata], item[:class], *item[:args])
          end
        end
      end

      module JobDecorator
        include Resque::Plugins::Clues::Util

        def self.included(klass)
          define_perform(klass)
          define_failed(klass)
        end

        private
        def self.define_perform(klass)
          klass.send(:define_method, :perform) do
            return _base_perform unless clues_configured?
            item = symbolize(payload)
            event_publisher.perform_started(now, queue, item[:metadata], item[:class], *item[:args])
            @perform_started = Time.now
            _base_perform.tap do
              item[:metadata][:time_to_perform] = time_delta_since(@perform_started)
              event_publisher.perform_finished(now, queue, item[:metadata], item[:class], *item[:args])
            end
          end
        end

        def self.define_failed(klass)
          klass.send(:define_method, :fail) do |exception|
            return _base_fail(exception) unless clues_configured?
            item = symbolize(payload)
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
