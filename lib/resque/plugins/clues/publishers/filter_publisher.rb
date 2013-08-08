require 'delegate'
require 'ostruct'
require 'set'

module Resque
  module Plugins
    module Clues
      # Event publisher that monitors events and indexes them for data mining.
      class FilterPublisher < SimpleDelegator

        attr_reader :filtered_events, :events, :filters

        # Initializer for the IndexerPublisher class
        # [Parameters]
        #  * options = Hash containing containing optional configuration parameters. See parameters below
        def initialize(options={})
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
            @filtered_events.push(apply_filters(event,@filters))
          end
        end

        def filter(selectors=[])
          filters.push(selectors)
          @filtered_events = apply_filters(@filtered_events, selectors)
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
          OpenStruct.new(current_event)
        end

        def apply_filters(events = [], selectors=[])
          binding.pry
          newevents = events.delete_if do |event|
            all_selectors = Set.new
            selectors.each do |selector|
              all_selectors << event.instance_eval(selector)
            end
    
            all_selectors.include?(false)

          end
          puts newevents
          newevents
        end


      end
    end
  end
end
