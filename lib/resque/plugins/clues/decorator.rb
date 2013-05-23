require 'digest/md5'
require 'time'

module Resque
  module Plugins
    module Clues
      module QueueDecorator
        include Resque::Plugins::Clues::Util
        include Resque::Plugins::Clues::EventHashable
        attr_accessor :event_publisher
        attr_accessor :item_preprocessor

        def push(queue, orig)
          return _base_push(queue, orig) unless event_publisher
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
            return orig unless item[:metadata]
            item[:metadata][:hostname] = hostname
            item[:metadata][:process] = $$
            item[:metadata][:time_in_queue] = time_delta_since(item[:metadata][:enqueued_time])
            event_publisher.dequeued(now, queue, item[:metadata], item[:class], *item[:args])
          end
        end

        private
        def time_delta_since(start)
          start.to_f - Time.now.utc.to_f
        end
      end
    end
  end
end
