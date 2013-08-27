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
      module QueueExtension
        # push an item onto the queue.  If resque-clues is configured, this
        # will First create the metadata associated with the event and adds it
        # to the item.  This will include:
        #
        # * event_hash: a unique item identifying the job, will be included
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
        def _clues_push(queue, item)
          return _base_push(queue, item) unless Clues.clues_configured?
          # Not wanting to refactor this into fine grained methods to avoid
          # polluting the resque namespace.
          item['clues_metadata'] = {
            'event_hash' => Clues.event_hash,
            'hostname' => Clues.hostname,
            'process' => Clues.process,
            'enqueued_time' => Time.now.utc.to_f
          }

          if Resque::Plugins::Clues.item_preprocessor
            Resque::Plugins::Clues.item_preprocessor.call(queue, item)
          end
          Clues.event_publisher.publish event_type: :enqueued,
                                        timestamp: Clues.now,
                                        queue: queue,
                                        metadata: item['clues_metadata'],
                                        worker_class: item[:class],
                                        args: item[:args]
          _base_push(queue, item)
        end

        # pops an item off the head of the queue.  This will use the original
        # pop operation to get the item, then calculate the time in queue and
        # broadcast a dequeued event.
        #
        # queue:: The queue to pop from.
        def _clues_pop(queue)
          _base_pop(queue).tap do |item|
            unless item.nil?
              if Clues.clues_configured? and item['clues_metadata']
                item['clues_metadata']['hostname'] = Clues.hostname
                item['clues_metadata']['process'] = Clues.process
                item['clues_metadata']['time_in_queue'] = Clues.time_delta_since(item['clues_metadata']['enqueued_time'])
                Clues.event_publisher.publish event_type: :dequeued,
                                              timestamp: Clues.now,
                                              queue: queue,
                                              metadata: item['clues_metadata'],
                                              worker_class: item['class'],
                                              args: item['args']
              end
            end
          end
        end
      end
    end
  end
end
