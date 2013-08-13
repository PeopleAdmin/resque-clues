require 'delegate'
require 'ostruct'
require 'set'

module Resque
  module Plugins
    module Clues
      # Event publisher that monitors events and indexes them for data mining.
      class FilterPublisher < SimpleDelegator

        attr_reader :filtered_events, :events, :filters

        # Initializer for the FilterPublisher class
        def initialize()
          @filters = []
          @filtered_events = []
          @events = []
        end

        # Publishes an event to the log.
        def publish(event_type, timestamp, queue, metadata, klass, *args)
          event = event_openstruct(event_type, timestamp, queue, metadata, klass, args)
          @events.push(event)

          if (@filters.length == 0)
            @filtered_events.push(event)
          else

            @filtered_events.push(apply_all_filters([event],@filters)).flatten!
          end
        end


        # 
        # Filter method applies a filter to events currently received and filered, and future events published
        # to FilterPublisher. The filters are applied as a set per call.
        # 
        # Example
        # 
        # [Parameters]  
        #  * filters = Array of strings that contain Ruby equations that can be evaluated against an event
        # 
        # [Examples]
        #  * event_list.filter("queue == 'testqueue'")
        #    * Filter event_list to only include events that occur in the testqueue queue  
        #  * event_list.filter("queue == 'testqueue' or queue == 'email")
        #    * Filter event_list to only include events that occur in the testqueue and email queues
        #  * event_list.filter("queue == 'testqueue'").filter("['enqueue', 'dequeue'].includes? even_type")
        #    * Filters list for only enqueue and dequeue events in the testqueue queue
        # [Return]
        #  * self
        def filter(*filters)
          unless filters.empty? 
            @filters.push(filters)
            @filtered_events = apply_filter(@filtered_events, filters)
          end
          self
        end

        def clear_filters
          @filters=[]
          @filtered_events = @events.dup
        end

        private
        def event_openstruct(event_type, timestamp, queue, metadata, klass, *args)
          current_event = {}

          current_event = {:event_type => event_type,
                           :timestamp => timestamp,
                           :queue => queue,
                           :metadata => metadata,
                           :klass => klass,
                           :args => args
                           }.merge(metadata)
          os_event = OpenStruct.new(current_event)
          os_event.args.flatten!
          os_event
        end

        def apply_all_filters(events = [], filter_sets=[])
          filter_sets.each do |filter_set|
            events = apply_filter(events, filter_set)
          end
          events
        end

        def apply_filter(events = [], filters=[])
          new_events = events.delete_if do |event|
            all_selectors = Set.new
            filters.each do |selector|
              all_selectors << event.instance_eval(selector)
            end

            all_selectors.include?(false)

          end
          new_events
        end


      end
    end
  end
end
